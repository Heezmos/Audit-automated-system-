"""Authenticated WSGI adapter. Serve only behind a buffering HTTPS ingress."""
import hashlib
import hmac
import json
import os
import re
import socket
import struct
import time
from datetime import datetime, timezone
from http import HTTPStatus

MAX_BYTES = 10 * 1024 * 1024
MAX_SIGNATURE_AGE = 7 * 86400
SOCKET_PATH = os.environ.get('CLAMD_SOCKET', '/run/clamav/clamd.ctl')


def scanner_token():
    path = os.environ.get('AUDIT_SCANNER_TOKEN_FILE')
    if path:
        with open(path, encoding='ascii') as secret:
            token = secret.read(256).strip()
    else:
        token = os.environ.get('AUDIT_SCANNER_TOKEN', '')
    if not 32 <= len(token) <= 128 or not re.fullmatch(r'[A-Za-z0-9_-]+', token):
        raise RuntimeError('Provide a 32–128 character URL-safe scanner secret')
    return token


TOKEN = scanner_token()


def reply(sock, deadline):
    """A successful suffix in an incomplete frame must never release evidence."""
    output = bytearray()
    while len(output) < 4096:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Engine deadline')
        sock.settimeout(remaining)
        chunk = sock.recv(min(512, 4096 - len(output)))
        if not chunk:
            raise RuntimeError('Incomplete engine response')
        output.extend(chunk)
        if b'\0' in output:
            frame, tail = bytes(output).split(b'\0', 1)
            if tail:
                raise RuntimeError('Multiple engine responses')
            return frame.decode('ascii', errors='strict')
    raise RuntimeError('Oversized engine response')


def command(command_bytes, data=None, timeout=35):
    deadline = time.monotonic() + timeout
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        sock.connect(SOCKET_PATH)
        sock.sendall(command_bytes)
        if data is not None:
            for start in range(0, len(data), 65536):
                sock.settimeout(max(0.001, deadline - time.monotonic()))
                chunk = data[start:start + 65536]
                sock.sendall(struct.pack('!I', len(chunk)) + chunk)
            sock.sendall(struct.pack('!I', 0))
        return reply(sock, deadline)


def engine_status():
    version = command(b'zVERSION\0', timeout=3)
    # VERSION reports the loaded database date, not a changeable file mtime.
    match = re.fullmatch(r'ClamAV ([^/\s]+)/([0-9]+)/(.+)', version)
    if not match:
        raise RuntimeError('Unrecognized engine version')
    updated = datetime.strptime(match[3], '%a %b %d %H:%M:%S %Y').replace(tzinfo=timezone.utc)
    age = (datetime.now(timezone.utc) - updated).total_seconds()
    if age < -300 or age > MAX_SIGNATURE_AGE:
        raise RuntimeError('Stale or future signatures')
    return version, updated.isoformat()


def application(environ, start_response):
    def respond(code, value):
        body = json.dumps(value, separators=(',', ':')).encode()
        start_response(f'{code} {HTTPStatus(code).phrase}', [
            ('Content-Type', 'application/json'), ('Cache-Control', 'no-store'),
            ('X-Content-Type-Options', 'nosniff'), ('Content-Length', str(len(body)))])
        return [body]

    auth = environ.get('HTTP_AUTHORIZATION', '')
    if not hmac.compare_digest(auth.encode(), ('Bearer ' + TOKEN).encode()):
        return respond(403, {'error': 'Access denied'})
    path, method = environ.get('PATH_INFO'), environ.get('REQUEST_METHOD')
    if environ.get('QUERY_STRING'):
        return respond(400, {'error': 'Query strings unsupported'})
    if path == '/health' and method == 'GET':
        try:
            engine_status()
            return respond(200, {'ready': True})
        except Exception:
            return respond(503, {'ready': False})
    if path != '/scan' or method != 'POST':
        return respond(404, {'error': 'Unknown operation'})
    size_header = environ.get('CONTENT_LENGTH', '')
    if environ.get('HTTP_TRANSFER_ENCODING') or not re.fullmatch(r'[0-9]{1,8}', size_header):
        return respond(400, {'error': 'Unsupported request framing'})
    size = int(size_header)
    if not 1 <= size <= MAX_BYTES:
        return respond(413, {'error': 'Unsupported upload size'})
    claimed_hash = environ.get('HTTP_X_EVIDENCE_SHA256', '')
    if not re.fullmatch(r'[a-f0-9]{64}', claimed_hash):
        return respond(400, {'error': 'Invalid evidence hash'})
    try:
        data = environ['wsgi.input'].read(size)
        if len(data) != size:
            return respond(400, {'error': 'Incomplete upload'})
        digest = hashlib.sha256(data).hexdigest()
        if not hmac.compare_digest(digest, claimed_hash):
            return respond(400, {'error': 'Hash mismatch'})
        version, updated = engine_status()
        result = command(b'zINSTREAM\0', data=data)
        if result == 'stream: OK':
            verdict = 'clean'
        elif re.fullmatch(r'stream: .+ FOUND', result):
            verdict = 'infected'
        else:
            raise RuntimeError('Scan incomplete')
        return respond(200, {'verdict': verdict, 'sha256': digest,
                            'engine': 'ClamAV', 'version': version,
                            'signaturesUpdatedAt': updated})
    except Exception:
        # Never log request bytes, hashes, bearer tokens or detection strings.
        return respond(503, {'error': 'Scan failed; quarantine must remain'})


if __name__ == '__main__':
    # Local container health check reveals no secret.
    engine_status()

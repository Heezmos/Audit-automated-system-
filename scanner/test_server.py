"""Contract tests with an in-memory ClamD transport; no live-engine claim."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

os.environ['AUDIT_SCANNER_TOKEN'] = 'test-only-token-' + 'x' * 32
spec = importlib.util.spec_from_file_location('scanner_server', Path(__file__).with_name('server.py'))
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class FakeEngine:
    def __init__(self, result=b'stream: OK\0', age=0):
        self.result, self.age = result, age
        self.received = []

    def __enter__(self):
        engine = self
        class Transport:
            def __init__(self, *_):
                self.input = bytearray()
                self.output = None
            def __enter__(self):
                return self
            def __exit__(self, *_):
                pass
            def settimeout(self, seconds):
                assert seconds > 0
            def connect(self, path):
                assert path == server.SOCKET_PATH
            def sendall(self, data):
                self.input.extend(data)
            def recv(self, count):
                if self.output is None:
                    if bytes(self.input) == b'zVERSION\0':
                        date = (datetime.now(timezone.utc) - timedelta(days=engine.age)).strftime('%a %b %d %H:%M:%S %Y')
                        self.output = ('ClamAV 1.4.3/12345/' + date).encode() + b'\0'
                    else:
                        assert self.input[:10] == b'zINSTREAM\0'
                        framed = bytes(self.input[10:])
                        data = b''
                        while True:
                            count_bytes, framed = framed[:4], framed[4:]
                            size = struct.unpack('!I', count_bytes)[0]
                            if not size:
                                assert not framed
                                break
                            assert len(framed) >= size
                            data += framed[:size]
                            framed = framed[size:]
                        engine.received.append(data)
                        self.output = engine.result
                chunk, self.output = self.output[:count], self.output[count:]
                return chunk
        self.patch = patch.object(server.socket, 'socket', Transport)
        self.patch.start()
        return self

    def __exit__(self, *_):
        self.patch.stop()


def request(data=b'audit evidence', **changes):
    environ = {'HTTP_AUTHORIZATION': 'Bearer ' + server.TOKEN,
               'PATH_INFO': '/scan', 'REQUEST_METHOD': 'POST', 'QUERY_STRING': '',
               'CONTENT_LENGTH': str(len(data)), 'wsgi.input': io.BytesIO(data),
               'HTTP_X_EVIDENCE_SHA256': hashlib.sha256(data).hexdigest()}
    environ.update(changes)
    status = []
    headers = []
    def start_response(value, fields):
        status.append(int(value.split()[0]))
        headers.extend(fields)
    body = b''.join(server.application(environ, start_response))
    return status[0], json.loads(body), dict(headers)


class ScannerTests(unittest.TestCase):
    def test_clean_stream_preserves_exact_bytes(self):
        data = bytes(range(256)) * 550
        with FakeEngine() as engine:
            status, body, headers = request(data)
            self.assertEqual(status, 200)
            self.assertEqual(body['verdict'], 'clean')
            self.assertEqual(body['sha256'], hashlib.sha256(data).hexdigest())
            self.assertEqual(engine.received, [data])
            self.assertEqual(headers['Cache-Control'], 'no-store')

    def test_infected_and_limit_alerts_remain_infected(self):
        for result in (b'stream: Eicar-Signature FOUND\0', b'stream: Heuristics.Limits.Exceeded FOUND\0'):
            with self.subTest(result=result), FakeEngine(result):
                self.assertEqual(request()[1]['verdict'], 'infected')

    def test_engine_errors_and_incomplete_success_are_rejected(self):
        for result in (b'stream: OK', b'stream: Scan failed ERROR\0', b'unknown: OK\0', b'INSTREAM size limit exceeded\0', b'stream: OK\0extra', b'x' * 4096):
            with self.subTest(result=result[:40]), FakeEngine(result):
                status, body, _ = request()
                self.assertEqual(status, 503)
                self.assertNotIn('verdict', body)

    def test_stale_and_future_loaded_signatures(self):
        for age in (8, -1):
            with self.subTest(age=age), FakeEngine(age=age) as engine:
                self.assertEqual(request()[0], 503)
                self.assertEqual(engine.received, [])

    def test_auth_before_body_or_engine(self):
        for auth in ('', 'Bearer wrong', 'Bearer é'):
            self.assertEqual(request(HTTP_AUTHORIZATION=auth)[0], 403)

    def test_size_and_framing(self):
        for header, expected in (('', 400), ('+4', 400), ('4,4', 400), ('-1', 400), ('0', 413), (str(server.MAX_BYTES + 1), 413)):
            with self.subTest(header=header):
                self.assertEqual(request(CONTENT_LENGTH=header)[0], expected)
        self.assertEqual(request(HTTP_TRANSFER_ENCODING='chunked')[0], 400)

    def test_hash_and_truncation(self):
        self.assertEqual(request(HTTP_X_EVIDENCE_SHA256='0' * 64)[0], 400)
        self.assertEqual(request(HTTP_X_EVIDENCE_SHA256='bad')[0], 400)
        self.assertEqual(request(CONTENT_LENGTH='100')[0], 400)

    def test_unknown_routes_and_queries(self):
        self.assertEqual(request(PATH_INFO='/remove')[0], 404)
        self.assertEqual(request(REQUEST_METHOD='DELETE')[0], 404)
        self.assertEqual(request(QUERY_STRING='token=secret')[0], 400)

    def test_missing_engine_is_unavailable(self):
        with patch.object(server, 'SOCKET_PATH', '/nonexistent/clamd.sock'):
            self.assertEqual(request()[0], 503)

    def test_authenticated_readiness(self):
        with FakeEngine():
            self.assertEqual(request(PATH_INFO='/health', REQUEST_METHOD='GET')[1], {'ready': True})
        with FakeEngine(age=8):
            self.assertEqual(request(PATH_INFO='/health', REQUEST_METHOD='GET')[0], 503)
        self.assertEqual(request(PATH_INFO='/health', REQUEST_METHOD='GET', HTTP_AUTHORIZATION='')[0], 403)

    def test_fragmented_protocol_response(self):
        class Fragmented:
            def __init__(self):
                self.chunks = iter([b'stre', b'am: ', b'OK', b'\0'])
            def settimeout(self, _):
                pass
            def recv(self, _):
                return next(self.chunks)
        import time
        self.assertEqual(server.reply(Fragmented(), time.monotonic() + 1), 'stream: OK')

    def test_invalid_secret_is_refused(self):
        for value in ('short', 'x' * 129, 'x' * 31 + ' '):
            with patch.dict(os.environ, {'AUDIT_SCANNER_TOKEN': value}):
                with self.assertRaises(RuntimeError):
                    server.scanner_token()


if __name__ == '__main__':
    unittest.main()

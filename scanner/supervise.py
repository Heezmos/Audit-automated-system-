"""Run all scanner processes as clamav; exit if a required process fails."""
import os
import signal
import subprocess
import time
from server import engine_status


def main():
    if os.geteuid() == 0:
        raise RuntimeError('Scanner must not run as root')
    children = []
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        updater = subprocess.Popen(['freshclam', '--stdout'], start_new_session=True)
        children.append(updater)
        deadline = time.monotonic() + 180
        while updater.poll() is None and not stopping and time.monotonic() < deadline:
            time.sleep(0.2)
        if stopping:
            return 0
        if updater.poll() != 0:
            raise RuntimeError('Initial signature update failed')
        children.remove(updater)
        daemon = subprocess.Popen(['clamd', '--config-file=/etc/clamav/clamd.conf'], start_new_session=True)
        children.append(daemon)
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline and not stopping:
            if daemon.poll() is not None:
                raise RuntimeError('Engine stopped during startup')
            try:
                engine_status()
                break
            except Exception:
                time.sleep(0.5)
        else:
            if stopping:
                return 0
            raise RuntimeError('Engine failed readiness')
        children.append(subprocess.Popen(['freshclam', '--daemon', '--foreground=true', '--stdout'], start_new_session=True))
        children.append(subprocess.Popen(['gunicorn', '--config', '/app/gunicorn.conf.py', 'server:application'], cwd='/app', start_new_session=True))
        while not stopping:
            if any(child.poll() is not None for child in children):
                raise RuntimeError('A required scanner process stopped')
            time.sleep(0.5)
        return 0
    finally:
        for child in children:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
        deadline = time.monotonic() + 10
        for child in children:
            try:
                child.wait(timeout=max(0.1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        print('Scanner unavailable; review private operator diagnostics', flush=True)
        raise SystemExit(1)

#!/bin/sh
set -eu
mkdir -p /run/clamav
chown clamav:clamav /run/clamav /var/lib/clamav
freshclam
clamd --config-file=/etc/clamav/clamd.conf &
for attempt in 1 2 3 4 5 6 7 8 9 10; do
 if [ -S /run/clamav/clamd.ctl ]; then break; fi
 sleep 1
done
[ -S /run/clamav/clamd.ctl ]
freshclam -d &
exec python /app/server.py

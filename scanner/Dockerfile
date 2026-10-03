FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends clamav-daemon clamav-freshclam && rm -rf /var/lib/apt/lists/*
COPY clamd.conf /etc/clamav/clamd.conf
COPY server.py /app/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
EXPOSE 8080
ENTRYPOINT ["/app/start.sh"]

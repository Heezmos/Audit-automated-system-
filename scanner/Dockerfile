FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends clamav-daemon clamav-freshclam && rm -rf /var/lib/apt/lists/*
ENV TZ=UTC PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY clamd.conf /etc/clamav/clamd.conf
COPY freshclam.conf /etc/clamav/freshclam.conf
COPY server.py supervise.py gunicorn.conf.py start.sh /app/
RUN mkdir -p /run/clamav /var/lib/clamav && chown -R clamav:clamav /run/clamav /var/lib/clamav && chmod +x /app/start.sh
USER clamav:clamav
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=3 CMD ["python", "/app/server.py"]
ENTRYPOINT ["/app/start.sh"]

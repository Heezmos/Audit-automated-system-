# Private evidence scanner deployment

Status: prepared source, not deployed. Twelve in-memory protocol/application tests pass. No real ClamAV scan, Docker build, HTTPS ingress test or deployment acceptance has been completed here. Sites Workers cannot execute this native service; use a separate owner-controlled Linux container host.

## Prepared protections

- Non-administrator `clamav` user for the adapter, engine and signature updater.
- Two synchronous Gunicorn workers, limited backlog, request headers and worker lifetime.
- Exact SHA-256 validation before sending any bytes to the engine; no deletion or modification of audit evidence.
- Only authenticated `/scan` and authenticated `/health` operations; no arbitrary URL, filesystem path, release or delete operation.
- ClamD Unix socket only. No exposed unauthenticated ClamD TCP listener.
- Seven-day maximum loaded signature age from `VERSION`; copied/touched database files cannot refresh this check. Container timezone is UTC.
- Strict bounded NUL-terminated engine replies. Missing engine, stale signatures, incomplete scans or errors return failure; audit quarantine remains.
- Supervised foreground processes: initial signature update and engine readiness precede HTTP startup, and required process exit stops the container.
- No application access/body/token logging. Operator diagnostics and reverse proxy retention still require review.

## Deployment resources still required

An owner-controlled Linux server/container platform, an HTTPS hostname/certificate, a private secret, signature-update network access, and restricted administrative access. The example reserves two CPUs and 3 GB memory; measure actual usage before confidential use. Hosting charges depend on the selected provider. Do not expose port 8080 or ClamD to the internet.

1. Have the operator create a random URL-safe scanner secret of 32–128 characters in the host secret store. The Compose example reads `/etc/audit-scanner/token` as a mounted secret, which must be readable by the container's `clamav` user and protected from other host accounts. Never commit it, paste it into chat, or pass it as a shell argument.
2. From this directory, build and start with `docker compose up --build -d`. Named signature storage inherits container directory ownership on first use. Existing volumes must already permit the container user to write. The filesystem is read-only except signature storage and bounded temporary mounts; capabilities are dropped and new privileges disabled.
3. Configure the host's HTTPS reverse proxy using `nginx.conf.example` after replacing the example hostname/certificate paths. The configuration belongs in the existing nginx `http` context. Validate with `nginx -t`. It buffers requests and caps global request rate/connections. Do not configure upstream retries or redirects. Verify a valid trusted TLS certificate and default-host rejection in the surrounding host configuration.
4. Keep the service isolated from production databases, host filesystem and other workloads. Permit only required signature update destinations for outbound traffic. Audit host/proxy logs to ensure tokens/bodies are absent; use encrypted temporary storage if the proxy spools request bodies. Disable core dumps and protect host swap. Pin reviewed container image digests before production and rebuild for security fixes; the supplied Python base tag and OS packages are not a reproducible vulnerability certification.
5. Run the acceptance checks below through the real HTTPS route, then set Sites runtime `AUDIT_SCANNER_URL` to its `/scan` URL and `AUDIT_SCANNER_TOKEN` to the same secret. These are server settings, never browser configuration. Publish to apply, verify a clean test upload, then rescan retained files. Do not mark scanning operational based solely on environment keys being present.

Run the prepared contract tests with `python scanner/test_server.py` from the repository root. They simulate protocol bytes and verdicts; they do not exercise the HTTP server, host network or real antivirus engine.

## Live acceptance before confidential use

| Check | Required result |
| --- | --- |
| Clean text fixture | HTTP 200, clean, exact SHA-256, recognized engine/version, current loaded signature date |
| Official EICAR test fixture | Infected; app retains it and blocks download/approval |
| Encrypted archive and scan-limit fixture | Blocked/infected/error; never released as clean after a skipped or incomplete scan |
| Missing/wrong bearer secret | Denied; request body not scanned and secret absent from logs |
| Hash mismatch / oversized input | Denied; retained audit originals unchanged |
| Engine stopped / updater stopped | Container exits or service unavailable; quarantine remains |
| Old loaded signatures / malformed reply | Failure; quarantine remains |
| Request flood / slow headers or body | Ingress limits and bounded workers confirmed under isolated testing |
| Container/process identity | No runtime process is root; no capabilities or public ClamD/8080 access |
| TLS / logs / storage | Valid HTTPS, no token/body logs, isolated host, protected temporary data |

Record who performed the acceptance checks, their UTC timestamps, versions and outcomes in the operational change record. Do not claim certification or guaranteed malware safety from a clean verdict. Independent security assessment, administrator MFA, separate immutable backups and a live restore drill remain separate outstanding controls.

References: [ClamD protocol](https://docs.clamav.net/manual/Usage/ClamdProtocol.html), [Gunicorn deployment](https://gunicorn.org/deploy/), [Docker container controls](https://docs.docker.com/engine/containers/run/).

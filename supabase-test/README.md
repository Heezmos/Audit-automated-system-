# Supabase test backend in Kwik-Pay

This is a deliberately separate test backend foundation. It does not replace the deployed Sites/D1/R2 app or migrate its records. The initial pilot covers real sign-in, case creation/editing, permanent revisions/activity, evidence registration/upload and quarantine. Findings, independent approvals, issued reports, recommendation verification, deadlines, transaction checks, AI and encrypted export from the full app have not been ported to this pilot. It is not production-ready.

## Live resources

- Supabase project: `lufkumfcxjimjylfmkjm` (Kwik-Pay).
- Private schema: `audit_test` (six tables, RLS on each).
- Private storage bucket: `audit-test-evidence`; up to 10 MB per object.
- Test workspace: `c98e40f8-44c5-425f-83df-b88cc8fb1f09`.
- Approved bootstrap email: `henrisonmoseray111@gmail.com`.
- No membership is activated yet. No verified Supabase Auth account with that email was found during setup. ChatGPT identity is separate from Supabase Auth identity.
- Public API exposes only named `audit_test_*` RPC operations; the data schema is not added to the exposed Data API schemas. Ordinary Kwik Pay users are not audit members.
- Web configuration contains a publishable key, not a service-role/secret key. It is intentionally public and grants no audit access by itself.

## Vercel test deployment

The connected Vercel deployment operation returned `Tool deploy_to_vercel not found`. No Vercel deployment was created or verified. Team project discovery returned no visible projects. The ready static interface is under `supabase-test/web`.

Import the `Heezmos/Audit-automated-system-` repository into a new, separate Vercel test project, using branch `codex/supabase-test-backend`. Select **Other** as framework, root directory `supabase-test/web`, no build command, and output directory `.`. Preserve Vercel deployment protection. The included `vercel.json` sets no-store, a strict CSP and security headers. Do not deploy the Cloudflare/Vinext repository root to Vercel.

Use a verified Supabase account matching the approved bootstrap email. Existing authentication settings, signup settings, redirect URLs and Kwik Pay roles were not changed. Do not auto-confirm arbitrary accounts or share passwords in chat. If the verified account uses another email, reconcile ownership explicitly before changing the test owner configuration. After successful sign-in, the backend checks the verified Auth email against the operator-approved workspace before activating the owner. It cannot create Auth users or give them Kwik Pay roles.

The pilot retains access tokens in memory only. Reloading/closing loses the local session; expiry requires another sign-in. Passwords are cleared after the sign-in request. This avoids persisting sessions locally but is not a production session-management implementation.

## Data controls and limits

Case updates require an expected version, preventing silent overwrites. Case history is written atomically by database triggers with canonical membership ID/name/email and UTC time. Case-list and activity-history reads also record the authenticated member and UTC time. Metadata, scan rows and activity cannot be updated/deleted/truncated through the supplied interface. The metadata registration happens before object upload, so upload failures do not erase its record. Storage receipt verification records a separate event after an object of the expected size exists; it does not establish a clean scan or prove SHA-256 byte integrity.

Uploads use unique workspace/evidence object paths and do not overwrite objects. Restrictive policies deny anonymous audit-bucket access and replacement/deletion and enforce membership even if a broader permissive storage policy is added later. Quarantined objects cannot be downloaded through ordinary authenticated Storage requests. No scan writer is granted to clients; only a separately reviewed scanner integration may insert verdicts. A clean verdict must match the metadata hash, be the latest scan, and have fresh scan/signature dates. **Live scanner integration is absent.** Provider administrators/service-role credentials can still override or destroy resources; independent immutable backups remain required.

The pilot intentionally supports only Planning and Fieldwork. This prevents an incomplete backend from pretending to approve or issue an audit. Case listing and activity use bounded cursor pagination. Each stored change keeps before/after data.

## Verification performed

`verify.sql` ran against the live PostgreSQL database using temporary fixture memberships and simulated JWT subject context inside a transaction, then rolled back. It passed owner create/update, canonical activity actors, before/after revisions, stale-version rejection, quarantine, denied client scan/history/member forgery, viewer read/write boundaries, nonmember isolation, anonymous RPC denial and delete/truncate guards. It does not prove real browser sign-in, storage upload transport, live antivirus scanning, Vercel serving or end-to-end behavior. No actual Auth users or payment records were created by these tests.

Security advisors returned no audit-specific findings after moving the tightly scoped bootstrap helper to the private schema with an invoker API wrapper. The shared project still reports other existing function advisories and disabled leaked-password protection; these require review before production. Existing Kwik Pay functions/settings were not altered.

## Move to a dedicated production project

1. Create a dedicated Supabase project and independent Vercel project/credentials; apply the recorded migrations there. The foundation migration checks for an existing audit schema because setup was iterated and verified before recording migration history.
2. Provision a production workspace and verified administrators. Migrate application memberships with explicit identity mapping; preserve the existing ChatGPT actor IDs/names as historical provenance rather than inventing Supabase attribution for old actions.
3. Port and verify all full-app workflows, approvals, file integrity checks, guards, rate limits, monitoring and encryption. Export and reconcile all existing records/files; do not discard the original app or its history during migration.
4. Connect an isolated scanner, independent immutable backups and live recovery; verify MFA, session revocation, retention, incident response and an independent security assessment.
5. Change the web configuration/API URL/publishable key/workspace and CSP hostname. Production must enforce its own environment classification and session/security controls; this test schema is intentionally constrained to environment `test`.
6. Complete signed-in browser and REST tests, data reconciliation, load testing and a restore drill before declaring production-ready.

Database backups do not replace separate storage-object backup. Shared project administrators/Auth/resources remain shared during this test; schema separation is not infrastructure isolation.

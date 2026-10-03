# Audit Workspace

Third operational release of the automated audit system. The deployment remains private. Auditor, reviewer and viewer memberships are configured inside the application; platform sharing must separately grant a person access before they can sign in. Institutional deployment, retention policies and external integrations remain planned.

## Working features

- Audit creation, institution, scope, lead and deadlines.
- Planning → Fieldwork → Review → Issued → Closed workflow.
- Private evidence upload and original-file download (10 MB limit), with SHA-256 fingerprint.
- Findings, evidence links, approval, institutional responses and recommendation deadlines.
- Draft/issued HTML reports with evidence registers; open a downloaded report in a browser to print or save as PDF.
- Search, stage filters, audit-register CSV export and recorded change history.
- Optional fictional demonstration cases, clearly marked as sample data.
- Team roles: owner manages memberships; auditors prepare cases; reviewers approve other authors’ work; viewers read only. Revoked members lose application access.
- CSV transaction checks (SLE): repeated references, same-date/payee/amount matches, missing records, invalid dates/amounts, configurable large amounts and median outliers. Import limit: 2,000 transactions / 512 KB.
- Check results preserve the source CSV as evidence. An auditor explicitly converts a flagged exception into an evidence-linked finding; duplicate conversions are blocked.
- Exceptions are screening results, not proof of fraud or AI conclusions.
- Recommendation follow-up records a responsible officer, deadline, corrective action and progress history.
- Completion submissions require evidence. A different authorised reviewer verifies them or returns them for changes, with a recorded assessment; verified recommendations may be reopened before audit closure.
- Issued audits accept completion evidence without reopening original findings. Audit closure requires all recommendations to be verified and all institution responses to be recorded. Previously closed audits remain locked.

Records use Cloudflare D1; evidence bytes use R2. Every API authenticates the platform visitor, resolves an active workspace membership, checks role permissions and scopes queries to the workspace owner. Site access remains owner-private. Finding authors cannot approve their own findings. Audit authors cannot provide independent audit sign-off. Findings require evidence and an independently recorded approval before audit sign-off; issue requires that sign-off. Role assignment does not send invitations or change platform sharing. The file fingerprint records original bytes; it does not establish authenticity of their contents. No AI assessment or government-system integration is active.

## Development and deployment

The app uses React, TypeScript and Vinext, producing a Cloudflare Worker. Install with `npm run install:ci`. Runtime requires `DB` (D1), `BUCKET` (R2), and trusted platform-injected authentication headers. Do not expose the Worker directly or accept arbitrary client identity headers. The hosting dispatcher owns ChatGPT sign-in and access policy.

Commands:

- `npm run dev` — development runtime.
- `npm run build` — Worker build.
- `npm run db:generate` — generate schema migrations.
- `node node_modules/typescript/bin/tsc --noEmit` — TypeScript check.
- `node tests/workspace.mjs` — workflow integration checks against an in-memory SQLite database and object-storage test double.

Migration files under `drizzle/` are applied by the hosting platform before deployment. The test harness exercises route handlers with a controlled identity; it does not replace end-to-end hosted sign-in or storage verification.

The original standalone `index.html` is preserved in the GitHub repository as the historical prototype; the application entrypoint is now `app/page.tsx`.


### Claude evidence assistant (prepared; service activation pending)
The AI workspace supports evidence summaries, questions, and editable draft findings using selected PDF, UTF-8 TXT or CSV evidence. Live generation requires a server-side ANTHROPIC_API_KEY; no key is configured in this deployment. No credentials belong in source control. ANTHROPIC_MODEL optionally overrides claude-sonnet-5-5. Set ANTHROPIC_WORKSPACE_ID when using a key that works across multiple Claude workspaces.

Requests accept up to three files, 2 MB each (6 MB total); text is limited to 60,000 characters per file and 120,000 combined. A workspace limit of ten attempts per hour includes failed attempts. Selected evidence is sent to the Anthropic Claude service only after an authorised user requests generation.

Text quotations must match source text; line references are derived by the server. PDF quotations and page references require manual checking against the original. Source references establish provenance, not the truth of the model's interpretation. Drafts never create or approve findings automatically: an auditor reviews and saves an unapproved finding. API tests use a mocked provider; live inference and live browser interaction have not been verified.


## Security hardening and operational limits
The private publication permits only the owner at the platform boundary. All app APIs additionally require platform-authenticated identity and active membership; directly exposing the Worker or trusting client-supplied identity headers is unsupported. Administrative roles do not grant platform sharing access. Membership invitations bind at first successful sign-in to the stable Site user ID; email changes retain a canonical audit identity, and revocation cannot be bypassed by taking another invitation.

The Worker enforces a same-origin request marker and fetch metadata checks on mutations, JSON/multipart content types, bounded streamed request bodies, no-store responses for records and pages, no-referrer, browser permission restrictions, anti-sniffing, HTTPS transport policy, and a per-request script nonce CSP. Only the app and ChatGPT may frame it. Production allows nonce-bearing inline scripts for framework hydration; it does not permit unrestricted inline scripts or eval. These controls also cover error responses returned by the request guard.

New evidence must match basic file signatures or UTF-8 text, retains private attachment-only downloads and SHA-256 fingerprints, and never uses its submitted filename as a storage path. Signature checks are not an antivirus scan or a full document validator. Spreadsheet exports neutralise formula prefixes including leading whitespace. Audit history and approval gates are enforced in the app, with optimistic concurrent-change rejection; a database administrator could still alter underlying records.

Before highly confidential institutional use: obtain an independent penetration test; enable MFA on ChatGPT, GitHub and any hosting/provider administrative accounts; verify account recovery and access reviews; document retention and incident response; configure, verify and restore-test database AND evidence backups; add malware scanning/quarantine and monitored security alerts. These operational controls have not been configured or independently verified here. Provider encryption, regional residency, backup retention and direct-origin isolation require verification with the hosting operator. This update is security hardening, not a security certification or a guarantee against attack.

Evidence downloads are recorded with the requesting member's canonical identity. Application errors are logged by category without database payloads. Production dependency audit after the pinned security updates reported zero known advisories; this is a point-in-time registry check and does not establish the absence of vulnerabilities.


## Permanent records and activity attribution
New activity events snapshot the authenticated Site user ID, name and canonical member email, with a server timestamp in UTC. New evidence metadata stores uploader identity, original filename and SHA-256; original bytes use unique object keys and conditional create-only writes. Registration is committed before the object write. A failed or ambiguous upload retains its registration and an unconfirmed status; no object is deleted as cleanup. Unconfirmed records require operator reconciliation rather than silent erasure.

Database triggers reject DELETE on audit cases, evidence, events, checks, revisions, AI runs, membership and workspace identity. Events/check results/revisions cannot be updated; evidence identity and metadata cannot change; INSERT OR REPLACE is blocked for permanent record IDs. Completed AI records cannot change. Audit cases can advance through the workflow, while triggers preserve their initial and earlier data in audit_versions, and app change events preserve before/after snapshots with the actor. Members can be renamed, assigned roles or revoked without changing their historical event identities. Existing cases remain intact, and their current data is archived on their next update without inventing historical actors.

The Activity screen uses cursor pagination beyond 100 events, full UTC dates/times, actor names/emails and saved-revision inspection. Legacy events and uploads with missing structured identity are explicitly labelled; previous names cannot be reconstructed reliably. Workspace reads, screen/case views, revision/history reads, evidence downloads and report/register/template export requests are logged. A request log does not prove that a browser completed saving a download; activity outside the application is not observable.

These are application and ordinary database-operation controls. They do not prevent a hosting administrator from dropping triggers, destroying the database/project or removing object storage directly. Hosting-level immutable retention/object lock, independently protected off-platform backups, and tested recovery remain required and unverified. The application has no object-deletion path; no claim of certified WORM storage is made.

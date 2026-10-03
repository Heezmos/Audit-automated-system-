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

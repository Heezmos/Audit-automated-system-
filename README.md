# Audit Workspace

First operational foundation for the automated audit system. This is an owner-private release for evaluating the workflow; institutional deployment, independent reviewers, roles, retention policies and external integrations remain planned.

## Working features

- Audit creation, institution, scope, lead and deadlines.
- Planning → Fieldwork → Review → Issued → Closed workflow.
- Private evidence upload and original-file download (10 MB limit), with SHA-256 fingerprint.
- Findings, evidence links, approval, institutional responses and recommendation deadlines.
- Draft/issued HTML reports with evidence registers; open a downloaded report in a browser to print or save as PDF.
- Search, stage filters, audit-register CSV export and recorded change history.
- Optional fictional demonstration cases, clearly marked as sample data.

Records use Cloudflare D1; evidence bytes use R2. Every API derives the owner from platform-authenticated identity and scopes queries to that owner. Site access remains owner-private. Approval in this release is an owner-recorded workflow action, not independent reviewer sign-off. The file fingerprint records original bytes; it does not establish authenticity of their contents. No AI assessment or government-system integration is active.

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

# Unattended deadline monitor

The Site is sole-owner private. Keep this audience and the dispatch authentication boundary intact. Do not expose the underlying Worker directly. `/api/monitor` is a limited shared updater for this workspace, not a caller-supplied owner/record writer. It never changes audit conclusions, findings, file contents, approvals or verified completion.

For each scheduled run:
1. Read `get_site` for this linked Site. Confirm active status and sole-owner private access (one owner, no other users/groups/external visitors). Stop and notify the owner if access has widened or cannot be verified; do not change sharing.
2. Obtain the supported `siwc_bypass_bearer_token` from that response. Never store it, put it in a prompt, print it, or send it to another origin. If unavailable, stop and report that monitoring could not run; never spoof visitor identity headers.
3. POST `{}` to the exact Site origin's `/api/monitor`, with `OAI-Sites-Authorization: Bearer <token>`, `Content-Type: application/json` and `X-Audit-Request: 1`. Reject redirects. Inspect HTTP and JSON success.
4. GET the same origin's `/api/monitor` with supported service access. Verify `lastRun.checkedAt` matches the successful POST and persisted counts are returned. Do not republish.
5. Leave reminders/escalations inside the app. Notify the owner through the scheduled task only if the run fails or new escalations were created. Do not send email/SMS or contact team members through other apps.

Check daily at 08:00 Africa/Freetown. The fixed initial policy warns three calendar days before the deadline, routes seven-day overdue items to active reviewers plus the owner, and fourteen-day overdue items to the owner. Due dates are evaluated as full UTC/Freetown calendar days; an item due today is not overdue until the following day. Verification submissions route to independent reviewers. Verified recommendations, closed audits and fictional sample audits are excluded.

All alerts, transitions, acknowledgements and completed check runs are permanent. Repeated checks do not duplicate the same active alert. Acknowledging an alert records attention and does not complete the audit action. New deadline/assignment/routing/level conditions supersede earlier alerts through recorded transitions. Concurrent audit changes are guarded by the case snapshot when alert transitions are persisted; a skipped stale snapshot is reconciled by the next check.

Workspace reads also evaluate deadlines, preserving routine monitoring if an unattended task is delayed. In-app recipients are snapshotted; a free-text officer/lead name is matched exactly to active member names or emails, otherwise routed to the owner. This is not proof of email/SMS delivery. Independent review remains mandatory.

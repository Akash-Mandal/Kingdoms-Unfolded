# AGENTS.md — Cost-saving rules (user-mandated)

## CI / APK builds cost money — manual only
- `.github/workflows/build.yml` triggers ONLY on `workflow_dispatch` + `v*` tags. Never re-add `push: branches: [main]`.
- Pushing to `main` must NEVER trigger a build.

## Agent commit/push behavior
1. Work locally, batch all edits for a whole task into minimal commits.
2. Do NOT `git push` until the whole task is finished.
3. Before any push that could cost (tag push, Run workflow), ASK the user via question tool: "Run APK build now? Yes / No".
4. If user says no / not needed: commit locally only (use `[skip ci]` in message if pushing docs/config that might match a tag pattern).
5. Only trigger a build yourself if essential (e.g. user asked to test on device, release tag requested).
6. NEVER auto-push after every small edit.

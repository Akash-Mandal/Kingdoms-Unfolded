# AGENTS.md — Cost-saving rules (user-mandated)

## CI / APK builds cost money — manual only
- `.github/workflows/build.yml` triggers ONLY on `workflow_dispatch` + `v*` tags. Never re-add `push: branches: [main]`.
- Pushing to `main` must NEVER trigger a build.

## Agent commit/push behavior
1. Work locally, batch all edits for a whole task into minimal commits.
2. Do NOT `git push` until the whole task is finished.
3. Only trigger a build if essential (user asked to test on device, release requested). Do NOT ask every time — run yourself only when essential.
4. If no build needed: commit locally, push with `[skip ci]` when pushing docs/config.
6. NEVER auto-push after every small edit.

# Store — Play track plan (internal → closed → open)

> Companion to `keystore/README.md` + `docs/BUILD.md`. No secrets here.

## Policy
- `version/code`: AAB-only incrementing (debug preset 3, release preset 4, bump release only).
- Debug APK is sideload/QA only — never uploaded to Play.
- Builds trigger on `workflow_dispatch` + `v*` tags only (manual-only per `AGENTS.md`).

## Tracks
1. **Internal**: first AAB (`v1.0.0-test` tag dry run, expect skip without secrets).
2. **Closed**: invite testers, privacy URL live, Data Safety submitted.
3. **Open/production**: staged rollout after closed feedback.

## Checklist
- [ ] Privacy page hosted (`narrative_settings.gd: PRIVACY_URL`).
- [ ] Data Safety: internet=true, LLM prompts, no ads, XOR-at-rest disclosed.
- [ ] `ANDROID_KEYSTORE_BASE64/ANDROID_KEYSTORE_PASSWORD/ANDROID_KEY_ALIAS/ANDROID_KEY_PASSWORD` set.
- [ ] Tag `v*` builds AAB via `build-release-aab` job.

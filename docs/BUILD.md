# Building the APK — CI Handbook

The Android APK is built **100% in the cloud** by GitHub Actions (`barichello/godot-ci:4.4`).
No PC and no local Godot install are ever required. This file documents the pipeline and the
traps found while getting it green (2026-08-20 session).

## Trigger

A build starts on:
- push to `main`
- any tag `v*`
- manual "Run workflow" button on the Actions page (no commit needed)

Download the result: repo → Actions → newest run → `kingdom-eternal-debug-apk` artifact →
install the `.apk` on your phone.

## Required export sequence (do not reorder)

1. `godot --headless --path . --import` — imports resources.
2. Copy image tooling into the runner HOME (the image installs under `/root`, but the
   runner's `$HOME` is `/github/home`):
   - `cp -r /root/.local/share/godot/export_templates/4.4.stable $HOME/.local/share/godot/export_templates/`
   - `cp /root/.config/godot/editor_settings-4.4.tres $HOME/.config/godot/`
3. Install the Android Gradle build template into the project:
   - `unzip -o $HOME/.local/share/godot/export_templates/4.4.stable/android_source.zip -d android/build/`
   - `echo "4.4.stable" > android/.build_version`
4. `godot --headless --path . --export-debug "Android" build/kingdom-eternal-debug.apk`

## Traps that caused silent failures

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `No export template found ... android_source.zip` | runner HOME vs image /root mismatch | copy step above |
| 2 | `Android build template not installed in the project.` | android_source.zip must be unpacked into `res://android/build` (the zip has no `android/` prefix) | step 3 |
| 3 | `"Min SDK" can only be overridden when "Use Gradle Build" is enabled` | removed min/target overrides while non-gradle | re-added them with gradle enabled |
| 4 | **`Cannot export ... configuration errors:` with an EMPTY message** | missing `textures/vram_compression/import_etc2_astc=true` in `project.godot` — validation fails silently on Linux hosts | keep that setting on |
| 5 | Debug-keystore errors | preset must carry `keystore/debug=/root/debug.keystore`, `debug_user=androiddebugkey`, `debug_password=android` (matches image default) | set in export_presets.cfg |
| 6 | `android_debug.apk`/`android_source.zip` not found in templates | non-gradle export still needs them; gradle path needs android_source.zip | current preset uses gradle; templates copied in step 2 |

## Signing & release notes

- Current builds are **debug-signed** (image default keystore) — fine for sideloading.
- Play Store releases later need a real upload keystore; store it as a GitHub secret and
  switch to `--export-release` with preset keystore fields (see barichello godot-ci docs).
- `android/` (build template) is git-ignored and recreated by CI each run.

## Settings grid (keep in sync)

| Setting | Value | Why |
|---|---|---|
| `gradle_build/use_gradle_build` | `true` | modern APK; also enables AAB later |
| `gradle_build/target_sdk` | `33` | image ships build-tools 33.0.2 / platform 33 |
| `gradle_build/min_sdk` | `24` | Godot minimum |
| `package/unique_name` | `dev.kingdometernal.kingdometernal` | app id |
| `permissions/internet` | `true` | LLM providers later |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` | Android validation requirement |
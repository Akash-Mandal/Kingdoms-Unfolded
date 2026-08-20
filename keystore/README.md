# Keystore — Debug vs Release

> Companion to `docs/BUILD.md`. Secrets are never committed — this folder is git-ignored (`*.keystore`, `*.jks`).

## Debug (current CI)

CI image `barichello/godot-ci:4.4` ships a default debug keystore:

```
keystore/debug=/root/debug.keystore
keystore/debug_user=androiddebugkey
keystore/debug_password=android
```

`export_presets.cfg` preset **Android** uses it and runs `godot --export-debug`. Fine for sideloading the APK artifact (`kingdom-eternal-debug.apk`). No secrets needed.

## Release (Play Store AAB)

Preset **Android Release** (`export_format=1` / AAB, `gradle_build/export_format=1`, `version/code=2`) is prepared for `--export-release`:

```
export_path=build/kingdom-eternal-release.aab
package/export_format=1
gradle_build/export_format=1
package/signed=true
keystore/release=res://keystore/release.keystore
keystore/release_user=REPLACE_WITH_KEYSTORE_ALIAS
keystore/release_password=REPLACE_WITH_KEYSTORE_PASSWORD
```

Replace the `REPLACE_WITH_*` placeholders locally or let CI overwrite them at build time.

### 1. Create a release keystore once (local machine)

```bash
keytool -genkey -v -keystore release.keystore -alias kingdom -keyalg RSA -keysize 2048 -validity 9125
# store password + alias + key password safely; then:
base64 -w 0 release.keystore > release.keystore.b64
```

Keep `release.keystore` out of git; back it up securely — losing it blocks Play Store updates.

### 2. Add GitHub Secrets (Repo → Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | contents of `release.keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `kingdom`) |
| `ANDROID_KEY_PASSWORD` | key password (often same as keystore password) |

> `barichello/godot-ci` examples use `RELEASE_KEYSTORE_*` — use either name consistently and update workflow `env:` / `sed` commands to match.

### 3. CI wiring (decode before `--export-release`)

Add before the export step in `.github/workflows/build.yml`:

```yaml
- name: Decode release keystore
  if: github.ref_type == 'tag'  # only on release tags
  env:
    KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
  run: |
    mkdir -p keystore
    echo "$KEYSTORE_BASE64" | base64 --decode > keystore/release.keystore
    # optionally inject alias/password into export_presets.cfg:
    # sed -i "s|REPLACE_WITH_KEYSTORE_ALIAS|${{ secrets.ANDROID_KEY_ALIAS }}|g" export_presets.cfg
    # sed -i "s|REPLACE_WITH_KEYSTORE_PASSWORD|${{ secrets.ANDROID_KEYSTORE_PASSWORD }}|g" export_presets.cfg

- name: Export release AAB
  run: |
    mkdir -p build
    godot --headless --path . --export-release "Android Release" build/kingdom-eternal-release.aab
```

See `docs/BUILD.md` traps for the required `android/build` template install and `$HOME` template copy — keep that order.

### 4. Local release build (optional)

```bash
mkdir -p keystore build
cp /path/to/release.keystore keystore/release.keystore
# edit export_presets.cfg keystore/release_user/password or pass via env
godot --headless --path . --export-release "Android Release" build/kingdom-eternal-release.aab
```

## Checklist

- [ ] `keystore/release.keystore` exists in CI (decoded from secret) for AAB builds
- [ ] `export_presets.cfg` preset `Android Release` has `export_format=1` / `gradle_build/export_format=1` / `package/signed=true`
- [ ] Play Console upload key matches this keystore
- [ ] Debug builds still use `/root/debug.keystore` (no change)

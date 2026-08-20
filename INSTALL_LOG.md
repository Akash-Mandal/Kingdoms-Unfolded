# INSTALL_LOG.md — Download & Install Tracker

> Living ledger for **Kingdom Eternal 3D**. Every download or installation performed for this
> project is logged here BEFORE it happens, so the whole venture can be reverted at any time.

**Rules**
1. No tool is installed and no file is downloaded without a row in this file first.
2. Removing an item = running its `Cleanup` command (or the delete/copy noted).
3. `Cleanup` commands are one-line and assume you're in the project root:
   `/storage/emulated/0/Coding/Gemini-CLI-Projects/Kingdom Unfolded`
4. Code written by the dev/AI is NOT a "download" — it is tracked by git, not this file.

---

## Estimated Removable Total (phone)

Tracked items that consume space on THIS phone:

| Category | Current size |
|---|---|
| New Termux packages | 0 MB |
| Downloaded art assets | 0 MB (stubs only — CC0 packs not yet fetched, see §2 #008) |
| Art/audio/texture stubs (text only, <80MB budget) | ~12 KB |
| Project code (all GDScript, shaders, JSON) | ~0.5 MB |
| Project cache (`.godot/`, git, curl) | ~0 MB |
| Cloud/PC tooling (NOT on phone) | 0 MB (see table below) |
| **REMOVABLE TOTAL (phone)** | **~0.5 MB code + 56 MB APK (optional)** |

---

## 1. Cloud / PC-side tooling (NOT on your phone)

Used remotely for building APKs. Size shown is the footprint on the cloud/PC, tracked so Manus
sessions or CI can be torn down cleanly.

| # | Date | What | Why | Source | Landed on | Size | Cleanup | Status |
|---|---|---|---|---|---|---|---|---|
| 001 | 2026-08-20 | Godot 4.4 export templates + Android SDK + JDK (container) | CI export of Android APK | `barichello/godot-ci:4.4` pulled on GitHub-hosted runner | GitHub Actions (ephemeral, torn down per run) | ~5 GB transient | none needed — container is auto-deleted | active (first run) |

## 2. Phone-side downloads & installs (ON this phone)

Anything here lives inside this project folder unless noted.

| # | Date | What | Why | Source | Landed at | Size | Cleanup | Status |
|---|---|---|---|---|---|---|---|---|
| 002 | 2026-08-20 | Debug APK artifact — Phase 0 (kingdom-eternal-debug.apk) | First playable build | GitHub Actions artifact | phone Downloads/ | 54 MB | delete file / uninstall app | superseded |
| 003 | 2026-08-20 | Debug APK artifact — Phase 1 (kingdom-eternal-debug.apk) | Living World: day/night, seasons, weather, 4 buildings, economy chain | GitHub Actions artifact | phone Downloads/ | 56 MB | delete file / uninstall app | active |
| 004 | 2026-08-20d | data/catalog/balance.json (6.7 KB) | Data-driven economy/balance tuning (seasonal yield, difficulty mults, upkeep) | local code (data-driven, no download) | data/catalog/balance.json | 6.7 KB | `rm data/catalog/balance.json` | active |
| 005 | 2026-08-20d | scripts/core/graphics_settings.gd — 4 presets (potato/balanced/high/ultra) | Graphics settings vault + auto-detect (render_scale, msaa, shadows, LOD, atlas) | local code | scripts/core/graphics_settings.gd + user://settings/graphics.json | ~7 KB + <1 KB vault | `rm scripts/core/graphics_settings.gd; rm user://settings/graphics.json` | active |
| 006 | 2026-08-20d | Perf patches — WorkerThreadPool (cap 800), viewport scaling, msaa, shadow atlas, MultiMesh | Launch perf hardening (30 FPS floor, <400 draw calls) | local code | scripts/npc/agent_manager.gd, scripts/core/graphics_settings.gd, project.godot | ~12 KB | `git checkout -- scripts/npc/ scripts/core/graphics_settings.gd project.godot` | active |
| 007 | 2026-08-20d | Bug fixes — Variant inference, Typed Array[Dictionary] restore, HUD 92px, season-aware smoke_test | CI green + playability fixes | local code | scripts/core/game.gd, scripts/tests/smoke_test.gd, scripts/ui/hud.gd | ~4 KB | `git checkout -- scripts/core/game.gd scripts/tests/smoke_test.gd` | active |
| 008 | 2026-08-20e | Art stubs — assets/README.md + audio/models/textures placeholders (CC0 not yet downloaded) | Keep clone & APK small; document Quaternius/Kenney CC0 source | stub (no download) | assets/README.md + assets/audio/ + assets/models/ + assets/textures/ | <2 KB (stub only) | `rm -rf assets/models/* assets/textures/*.png assets/audio/*.ogg` | stub |
| 009 | 2026-08-20e | AAB stub — export_presets.cfg orientation + Play Store keystore placeholder | Prepare signed AAB (gradle, screen/orientation=0, support_small_screens) | local code | export_presets.cfg + keystore/release | <1 KB | `git checkout -- export_presets.cfg` | stub |
| 010 | 2026-08-20e | Save system — scripts/core/save_slots.gd (5 slots + autosave every 5 turns + export .kingdom) | Launch persistence (slot_name, autosave, export/import) | local code | scripts/core/save_slots.gd + user://saves/ | ~5 KB + saves | `rm -rf user://saves/*; rm scripts/core/save_slots.gd` | active |

## 3. Termux packages installed for this project

| # | Date | Package | Why | Size | Cleanup (`pkg remove ...`) | Status |
|---|---|---|---|---|---|---|
| — | — | *none yet — git, curl, unzip, tar, nano, vim already present* | — | — | — | — |

## 4. Repo / tooling baseline (already present, NOT installed by us)

| Item | Where | Notes |
|---|---|---|
| git 2.55.0 | `/data/data/com.termux/files/usr/bin/git` | pre-installed |
| curl / unzip / tar | `/data/data/com.termux/files/usr/bin/` | pre-installed |
| nano / vim | `/data/data/com.termux/files/usr/bin/` | pre-installed |
| Termux base install | `/data/data/com.termux/files/usr` | 1.1 GB, pre-existing, untouched |

---

*First entry: 2026-08-20 — project scaffold + git init (code, tracked by git).*
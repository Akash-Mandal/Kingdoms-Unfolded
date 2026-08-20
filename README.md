# Kingdom Eternal 3D

A living medieval kingdom simulation for Android — deep strategy sim + individual NPC lives,
rendered as a 3D world in **Godot 4.4 (GDScript)**, with a hybrid AI narrative layer
(local-first, optional cloud LLM providers).

**Status: Phase 0 (Foundations)** — procedural terrain, orbit camera, HUD, and the
Coordination Engine monthly-turn skeleton are in place. Every commit is CI-built into an
installable Android APK.

## Folder layout

```
├── project.godot          Engine config (Mobile renderer, Android presets)
├── export_presets.cfg     Android export preset ("Android" → APK)
├── scenes/                Scenes (.tscn, minimal — world is built in code)
├── scripts/
│   ├── core/game.gd       Autoload "Game" — Coordination Engine + save/load
│   ├── world/             main.gd, terrain.gd (seeded worldgen), camera_controller.gd
│   ├── ui/hud.gd          HUD overlay (resource bar, events, next-turn)
│   ├── net/               Narrative provider adapters (Phase 5)
│   └── tests/smoke_test.gd  Headless CE test (runs in CI)
├── assets/                CC0 art packs (tracked in INSTALL_LOG.md)
├── data/saves/            Save files (user:// at runtime; exports go here if saved manually)
├── .github/workflows/     CI: build + smoke-test on every push
└── INSTALL_LOG.md         Download/install ledger (reversible setup)
```

## Dev workflow (no PC needed)

1. **Edit code on this phone** (Termux: `nano scripts/...`).
2. **Commit & push** to your GitHub repo.
3. **GitHub Actions** imports assets and exports a signed **debug APK** automatically.
4. **Download the artifact** from the Actions run page on your phone browser.
5. Install: `adb install` or open the APK file.

```
phone: write code → git push → GitHub Actions (godot in Docker) → APK artifact → install on phone
```

To trigger a build: push to `main`, push a `v...` tag, or use the **"Run workflow"** button
(Actions tab) — no commit needed.

## First-time GitHub setup (one-time)

```bash
git remote add origin https://github.com/YOUR_USER/kingdom-eternal.git
git branch -M main
git push -u origin main
```

Then open the **Actions** tab → run the workflow → grab the APK from the run page.

## Running the CE test (headless, anywhere Godot 4.4 exists)

```bash
godot --headless --path . --script res://scripts/tests/smoke_test.gd
```

## House rules

- Every download/install is logged in `INSTALL_LOG.md` *before* it happens.
- Build artifacts, keystores and caches are git-ignored; code is the single source of truth.
- No API keys are ever committed (LLM provider keys are enter-the-device settings later).

## Roadmap

Phase 0 Foundations → Living World → The People → Systems → AI Soul → Launch.
Monetization is deferred; this is a personal, polished-hobby project first.
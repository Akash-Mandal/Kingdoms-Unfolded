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
| Downloaded art assets | 0 MB (none yet) |
| Project cache (`.godot/`, git, curl) | ~0 MB |
| Cloud/PC tooling (NOT on phone) | 0 MB (see table below) |
| **REMOVABLE TOTAL (phone)** | **~0 MB** |

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
| — | 2026-08-20 | *none yet* | — | — | — | — | — | — |

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
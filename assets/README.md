# Assets — Art Direction Stubs (GRAND_PLAN §11)

> Stylized low-poly, warm key + cool sky fill, soft shadows/fog, filmic tonemap. Readable silhouette at 10/50/200m (LOD A/B/C). 1 unit = 4m.

## CC0 Sources (tracked in `INSTALL_LOG.md`)

| Pack | Author | License | Intended Use | Status |
|---|---|---|---|---|
| Medieval UltraPack | Quaternius | CC0 | buildings, props, characters, vegetation | **stub — not yet downloaded** |
| Kenney packs (Medieval / Prototype / Nature) | Kenney | CC0 | prototyping, UI icons, supplementary props | **stub — not yet downloaded** |

No binaries committed yet — placeholders keep clone & APK small.

## Procedural Assembly Note

Visual variety is **assembled in code**, not by heavy assets:

- Seeded placement + palette tint + scale jitter per `scripts/world/terrain.gd` + `shaders/terrain.gdshader` (snow / season_tint).
- Kit-bashed prefabs from 6–10 base meshes → dozens of variants via `MultiMeshInstance3D` and material overrides (banner accent, hostile desaturation, quest gold rim).
- Texture atlases + `etc2_astc` VRAM compression (see `assets/textures/README.md`).
- Foliage billboards + baked GI for static geometry; water = additive transparent shader.

When CC0 packs are imported, they land under `assets/models/` and `assets/textures/` and are atlas-packed; raw zips are not kept in git.

## Layout

```
assets/
├── README.md          # this file (§11)
├── audio/README.md    # adaptive score stub (§12)
├── audio/adaptive_score.json  # 4-layer placeholder
├── models/            # .glb from packs (git-ignored if >5MB — use LFS or CI fetch)
├── textures/README.md + atlas_placeholder.md
└── shaders/terrain.gdshader (verified exists)
```

## Budget — Keep Release <80MB

- `project.godot` uses `Mobile` renderer + `etc2_astc` + `msaa_3d=1`.
- Current debug APK ~56 MB; release target **<80 MB**.
- Rule: no single asset >2 MB; total `assets/` (imported) <25 MB; compress audio to Ogg Vorbis q0.4; prefer `.glb` + atlas over individual PNGs.
- CI gate: `ls -lh` check in workflow; if `export/*.apk` >80 MB, fail.

## Adding Real Assets

1. Log row in `INSTALL_LOG.md` §2 **before** downloading (source URL, size, cleanup `rm`).
2. Download to `/tmp`, unpack, keep only needed `.glb`/`.png`/`.ogg`.
3. Run Godot import once, verify `*.import` uses `compress/mode=2` + `vram_compression`.
4. Commit with LFS if needed; update this README status to `imported`.

## Cleanup

```bash
rm -rf assets/models/* assets/textures/*.png assets/audio/*.ogg
```

See `INSTALL_LOG.md` for reversible ledger.

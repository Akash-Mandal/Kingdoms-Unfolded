# atlas.png — Placeholder

No binary yet (keeps clone <1MB and APK <80MB).

Expected file: `assets/textures/atlas.png` (2048×2048, VRAM `etc2_astc`, mipmaps on) + `atlas.png.import`.

Content: terrain splat + building + foliage regions, sampled by `shaders/terrain.gdshader` (`season_tint`, `snow_amount`, `snow_color`).

When CC0 packs (Quaternius / Kenney) are imported, repack their albedos into this atlas; do not commit individual 1K PNGs.

Create via: Godot import or external packer → verify size <2MB → update `assets/textures/README.md` → log in `INSTALL_LOG.md`.

Cleanup: `rm assets/textures/atlas.png assets/textures/atlas.png.import`

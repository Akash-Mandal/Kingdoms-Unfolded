# Textures — Atlas Placeholder (GRAND_PLAN §11/§19)

> Target <80MB APK: one atlas > many PNGs. `etc2_astc` VRAM compression, `Mobile` renderer, baked GI.

## Atlas Strategy

- **Single atlas**: `atlas.png` 2048×2048 (max) packs terrain splat (plains/forest/hills/rock/sand/snow), building albedo, foliage.
- Import: `compress/mode=2 (VRAM)`, `compress/hdr_compression=0`, `mipmaps=true`, `repeat=disabled`, `filter=linear`.
- Shader uses `season_tint` + `snow_amount` (see `shaders/terrain.gdshader`) — no extra textures per season.
- Foliage billboards share same atlas region; water is shader-only.

## Placeholder

- `atlas_placeholder.md` — notes where `atlas.png` + `atlas.png.import` will live; no binary committed.
- Until atlas is built, `terrain.gdshader` tints `COLOR.rgb` procedurally; terrain still renders.

## Budget

- Atlas PNG <2 MB source, <1 MB VRAM. Total `assets/textures/` <5 MB. Audio + models + textures combined <25 MB to hold APK <80 MB.
- Procedure: pack with `TexturePacker` or Godot `AtlasTexture`; commit only final `atlas.png`.

## Cleanup

```bash
rm assets/textures/atlas.png assets/textures/atlas.png.import
```

Tracked in `INSTALL_LOG.md` §2.

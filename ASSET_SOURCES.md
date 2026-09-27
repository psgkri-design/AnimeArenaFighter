# Asset Sources

This project keeps gameplay code usable without downloaded third-party assets. Android CI fetches pinned CC0 character assets before export; fighter.gd falls back to procedural models when those files are absent.

## Currently integrated in Android builds

- **KayKit Character Pack: Adventures 1.0** — Kay Lousberg / KayKit.
- License: **CC0** (the build workflow downloads the upstream LICENSE.txt alongside the models).
- Runtime files used: Rogue_Hooded.glb, Mage.glb, Knight.glb, Rogue.glb.
- Source is fetched by `.github/workflows/build-android.yml`.

## Evaluated for the next character-quality pass

- **Quaternius — Universal Base Characters**.
- License: **CC0**.
- Humanoid-rigged stylized base characters, supplied in glTF/FBX/Blend formats.
- Planned use: higher-detail body bases while keeping each fighter's custom silhouette, colors, weapons and accessories.

## Project rule

Only redistribution-friendly assets with a clear license may be added to production builds. Keep the license/provenance record next to every external asset family.

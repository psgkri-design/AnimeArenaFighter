# Anime Arena Fighter — Game Changelog

This file tracks meaningful gameplay, graphics, animation, UI, optimization and build changes. Existing history is preserved and new work is appended.

## Update 01 — Initial playable prototype

### Added
- Android 1v1 arena-fighter prototype.
- Third-person lock-on camera.
- Touch joystick and mobile action buttons.
- Light combo, heavy attack, dash, dodge, block, parry, four skills and ultimate.
- Enemy AI, KO flow, rematch and result screen.
- 30/60 FPS support and Android ARM64 export.

### Graphics
- Initial toon shader and emissive energy shader.
- Procedural arena and prototype character visuals.

## Update 02 — Four-fighter roster and character select

### Added
- Four fighters with unique stats and skill identities.
- Independent player and opponent selection.
- Easy, Normal and Hard AI difficulty.
- Character descriptions, roles, stats and skill lists.

### Changed
- Landscape-only mobile presentation.
- Match flow preserves selected fighter, opponent and AI difficulty.

### Graphics
- Expanded arena lighting and cyber-city backdrop.
- Integrated KayKit CC0 rigged character bases for Android builds.

## Update 03 — HUD and arena polish

### Added
- 99-second round timer and timeout result logic.
- Fighter names and skill strip in battle HUD.
- Cyber-city towers, emissive bands and outer gates.

### Optimization
- Backdrop uses static meshes and avoids additional shadow-casting lights.

## Update 04 — Start Battle reliability hotfix

### Fixed
- Fixed GDScript parse error in fighter skill-damage tables.
- Fixed projectile homing type inference error.
- Fixed city-tower initialization calling look_at before entering the scene tree.
- Added startup validation so broken scripts cannot be published as a successful APK.

## Update 05 — Automated full combat smoke validation

### Added
- Added a headless full-game smoke test covering Character Select → Start Battle → arena spawn → damage → KO → rematch → character select.
- Smoke test runs through all four player variants.
- Added runtime animation-clip audit for every fighter model used in CI.
- Added canonical third-party license registry under assets/ThirdParty/ASSET_LICENSES.md.

### Changed
- Android CI now validates the real gameplay flow, not only scene startup.

### Fixed
- Future Character Select / Start Battle regressions now fail the build automatically before APK upload.

### Optimization
- Validation is headless and adds no runtime cost to Android builds.

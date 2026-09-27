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

## Update 06 — Combat animation state system

### Added
- Connected imported KayKit AnimationPlayer clips to runtime fighter states.
- Added state-driven Idle, run, backward walk, left/right strafe, four-direction dodge, block, block-hit, hit reaction and death playback.
- Added fighter-specific attack animation sets: dual-wield for Succubus Assassin, spell/unarmed for Arcane Mage, two-handed melee for Templar Knight and fast unarmed attacks for Cyber Bunny.
- Added attack-specific animation metadata for light combo steps, heavy attacks, skills and ultimates.
- Added subtle procedural body lean/bob layered on top of imported animation playback.

### Changed
- CharacterBody movement remains code-driven; imported animations are visual-only so root motion cannot reduce touch-control responsiveness.
- Combat camera now adds speed-based dynamic FOV and a small impact FOV impulse.

### Animation
- Eliminated the previous idle-only external-model behavior.
- Added blend times between locomotion/defense/reaction states to reduce snapping.
- Added alternating Hit_A / Hit_B reactions and Block_Hit feedback.

### Optimization
- Reuses the AnimationPlayer already embedded in each GLB; no per-frame animation object allocation.

## Update 07 — Pooled combat VFX and impact feedback

### Added
- Added a preallocated 24-slot combat VFX pool for impact bursts, slash arcs, dash trails, energy charge and aura effects.
- Added fighter combat-FX events for attacks, skills, dashes and dodges.
- Added SFX hook events for swing, impact, dash, energy, parry and ultimate cues.
- Added short strength-scaled hit-stop on impacts and parries.

### Changed
- Replaced per-hit Node3D/Mesh/Tween creation and queue_free calls with reusable pooled effects.
- Ultimate startup now triggers a pooled aura effect.
- Perfect evade and parry now use dedicated pooled visual feedback.

### Graphics
- Attack startup now produces readable fighter-colored slash/energy shapes.
- Dash movement now leaves a brief directional energy streak.

### Optimization
- Combat VFX meshes and shader materials are preallocated once.
- Hit-stop is disabled in headless CI so automated gameplay tests remain deterministic.
- VFX pool exposes LOW/MEDIUM/HIGH ray-count scaling for the upcoming quality presets.

## Update 08 — Mobile graphics presets and combat HUD telemetry

### Added
- Added LOW / MEDIUM / HIGH graphics presets selectable from Character Select.
- Added runtime 3D render-scale control, MSAA scaling, positional shadow-atlas scaling and 30/60 FPS caps.
- Added VFX-density scaling so LOW/MEDIUM/HIGH uses fewer or more pooled spark rays.
- Added lock-on status indicator to the combat HUD.
- Added live per-skill cooldown timers with READY state.

### Changed
- LOW targets weaker devices with 0.72 render scale, no MSAA, no positional shadow atlas and a 30 FPS cap.
- MEDIUM is the default target with 0.88 render scale, 2x MSAA and 60 FPS.
- HIGH uses native 3D scale, 4x MSAA, larger shadow atlas and 60 FPS.
- Main directional shadow distance now scales with the selected graphics preset.

### Optimization
- Graphics settings are applied at runtime without reloading the match.
- CI smoke-test now verifies LOW and MEDIUM FPS caps in addition to the full battle loop.

## Update 09 — Animated 3D Character Select preview

### Added
- Added a live 3D preview viewport to Character Select.
- Preview uses the same fighter construction pipeline and imported rigged model used by gameplay.
- Selected PLAYER or OPPONENT can be previewed by tapping their roster card.
- Added explicit PLAYER PREVIEW / OPPONENT PREVIEW context label.
- Added selected-state styling for all eight player/opponent roster cards.

### Changed
- Roster cards now show fighter initials plus combat-class text instead of initials only.
- Moved the central VS mark upward to make room for the 3D character presentation.

### Animation
- Preview models run their imported idle animation through the same AnimationPlayer integration as combat fighters.

### Optimization
- Preview SubViewport rendering and its node processing are disabled as soon as a match starts.
- Preview rendering resumes only when returning to Character Select.
- CI smoke-test now verifies that the preview fighter and its AnimationPlayer are created successfully.

### Fixed — Update 09 hotfix
- Renamed a Character Select local variable that collided with GDScript's reserved `class_name` keyword and prevented the preview HUD script from compiling.

## Update 10 — Stylized character material pass

### Graphics
- Converted imported rigged-character materials at runtime to Godot's toon diffuse and toon specular lighting modes.
- Added subtle rim lighting to improve anime-style silhouette readability against the arena background.
- Added material-aware tuning for hair, eyes and general body/clothing surfaces.
- Preserved each imported GLB's original albedo/normal/roughness texture assignments by duplicating the existing material instead of replacing it with an untextured shader.

### Changed
- Hair uses stronger rim response and controlled roughness.
- Eyes use a tighter, cleaner specular response.
- Clothing/body surfaces keep a broader matte range for readable stylized shading.

### Optimization
- Materials are duplicated and configured once when the fighter model is built; there is no per-frame material allocation.
- The pass uses built-in mobile-compatible BaseMaterial3D features rather than an expensive custom multi-pass outline.

## Update 11 — Arena lighting and batched environment detail

### Added
- Added a batched sci-fi floor-linework layer built with one MultiMesh instead of dozens of separate draw calls.
- Added radial combat-zone guides and segmented concentric rings to give the arena stronger depth and scale.
- Added restrained compatibility-renderer bloom and distance fog for a more cinematic anime presentation.

### Changed
- Increased ambient fill slightly so fighter faces and silhouettes stay readable.
- MEDIUM/HIGH now use environment glow and atmospheric fog; LOW disables both automatically.
- HIGH receives slightly stronger bloom/fog while MEDIUM keeps a conservative mobile target.

### Graphics
- Arena emissive geometry now has more visible structure under fighters without cluttering the central combat area.
- Distant cyber-city geometry fades more naturally into the background.

### Optimization
- Floor decoration is rendered through a single MultiMesh batch.
- LOW preset disables glow and fog completely.
- No additional realtime shadow-casting lights were introduced.

## Update 12 — Combat HUD readability and lock-on feedback

### Added
- Added compact fighter badge blocks beside both health bars using each fighter's roster identity/color.
- Added a world-projected lock-on marker that tracks the opponent on screen and hides automatically when lock-on is disabled or the target is behind the camera.
- Added live Ultimate percentage and pulsing ULT READY feedback.
- Added an original project icon so Android/Godot builds no longer report a missing project icon.

### Changed
- Combat HUD now communicates target state, fighter identity, skill cooldowns and ultimate readiness without covering the arena.

### UI
- Fighter badges inherit selected roster colors.
- Lock marker is projected from the enemy's upper-body position for clearer target readability.

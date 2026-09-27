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

## Update 13 — Round presentation flow

### Added
- Added a short animated READY → FIGHT banner when a match begins.
- Added a dedicated controls-enabled gate so player input and enemy AI do not start moving before the round presentation finishes.

### Changed
- Character Select now transitions into a clearly staged arena start instead of dropping directly into active combat.
- Camera receives a very small impulse on FIGHT for visual punch.

### Fixed
- Headless CI bypasses the presentation delay so automated combat validation remains fast and deterministic.

## Update 14 — Procedural combat look-at and bone-anchored VFX

### Added
- Added runtime Skeleton3D discovery for imported fighter rigs.
- Added validated head/chest bone lookup using the actual KayKit skeleton names.
- Added subtle procedural combat look-at on chest and head while a valid opponent is targeted.
- Added right-hand-slot lookup and a bone-derived combat FX origin.

### Changed
- Slash/charge VFX now originate from the fighter's animated right-hand attachment point instead of the CharacterBody center.
- Look-at offsets are deliberately clamped and low-weight so imported attack/reaction animations remain dominant.

### Animation
- Fighters maintain stronger eye-line/body awareness toward their opponent while preserving authored AnimationPlayer clips.
- Head/chest look-at is skipped on death and when no target exists.

### Optimization
- Skeleton/bone references are resolved once during model setup.
- Procedural look-at touches only two bones and avoids full-body IK solvers on the flat arena.
- CI now verifies head, chest and right-hand-slot bones before APK publication.

## Update 15 — Rigged weapon asset integration

### Added
- Integrated textured CC0 KayKit weapon meshes from the same character pack used by the fighter bases.
- Succubus Assassin now uses two rig-attached dagger assets.
- Arcane Mage now uses a rig-attached staff asset.
- Templar Knight now uses a rig-attached colored two-handed sword asset.
- Cyber Bunny now uses a rig-attached one-handed blade asset.
- Added Android CI download/import for weapon glTF, bin and shared texture dependencies.

### Changed
- Weapons are attached to the imported `handslot.l/r` bones through BoneAttachment3D, so they follow authored combat animations instead of floating at fixed CharacterBody coordinates.
- Weapon materials receive the same toon/specular/rim stylization pass as character materials.

### Graphics
- Replaced prototype weapon presentation with authored textured accessory meshes designed for the same character pack/scale.

### Fixed
- CI smoke-test now requires every fighter variant to resolve at least one bone-attached weapon asset.

### Optimization
- Weapon assets share the KayKit texture atlases and are loaded once with the fighter scene; no runtime spawning occurs per attack.

## Update 16 — Weapon trails, Ultimate aura and projectile polish

### Added
- Added continuous bone-anchored slash trail bursts during the active frames of melee attacks.
- Added an Ultimate-charge aura that becomes more frequent as the meter approaches 100%.
- Added layered rotating energy rings and pulse animation to projectiles.

### Changed
- Heavy and Ultimate attacks use stronger hand-driven trail intensity than light attacks.
- Ultimate aura uses the fighter's own color identity and only runs while the fighter is alive.

### Graphics
- Melee attacks now visually trace the animated hand/weapon arc rather than showing only a single startup slash.
- Energy projectiles have a more readable silhouette and motion at combat distance.

### Optimization
- Weapon trails reuse the existing 24-slot pooled combat VFX system.
- Aura pulses are rate-limited and do not spawn every frame.
- Projectile polish reuses one shared shader material inside each projectile instead of creating separate materials for every ring.

## Update 17 — Cinematic Ultimate camera pass

### Added
- Added a timed side-arc camera move for Ultimate attacks instead of a fixed static cinematic angle.
- Added fighter-dependent camera side selection so fast fighters and power fighters do not all use the same composition.
- Added a tighter-to-wider FOV curve through the Ultimate camera beat.

### Changed
- Ultimate framing now eases around the attacker and victim while keeping both readable.
- Camera collision checks now exclude both the player and the target, reducing close-range camera pops caused by fighter collision bodies.
- Cinematic camera positions still pass through the world collision solver before being applied.

### Graphics
- Ultimate attacks now have a visibly distinct camera language from normal combat without adding long non-interactive cutscenes.

### Optimization
- Camera arc uses simple interpolation and vector math only; it adds no new scene nodes or allocations during combat.

## Update 18 — Damage and low-health screen feedback

### Added
- Added a lightweight fullscreen HUD shader for edge-based low-health danger feedback.
- Added a short damage flash pulse whenever the player loses health.
- Added gradual danger intensity below roughly 38% health instead of a sudden binary warning.

### Graphics
- Damage feedback is strongest near the screen edges so the center combat area remains readable.
- Low-health tint is restrained and compatible with the existing anime/cyber palette.

### Optimization
- Uses one fullscreen CanvasItem shader and two scalar uniforms.
- No extra particles, textures or per-hit scene allocation are required.

## Update 19 — Fighter-specific combat VFX language

### Added
- Added four distinct pooled attack-FX profiles tied to fighter identity.
- Succubus Assassin uses thin, fast alternating dual-slash arcs.
- Arcane Mage uses rotating spherical arcane bursts.
- Templar Knight uses broad, heavy cleave shapes.
- Cyber Bunny uses elongated plasma/pulse streaks.

### Changed
- Active attack frames now keep each fighter's VFX profile instead of sharing one generic slash effect.
- Skill startup effects follow the same fighter-specific visual language.
- Ultimate startup still uses the larger aura treatment for cinematic readability.

### Graphics
- Fighter silhouette, animation and effect shape now reinforce the intended combat archetype instead of relying on color alone.

### Optimization
- All four new effect profiles reuse the same existing pooled nodes, meshes and materials; no extra runtime allocation path was introduced.

## Update 20 — Stylized sky and distant arena landmarks

### Added
- Added a lightweight custom sky shader with deep-blue zenith, magenta horizon and dark lower gradient.
- Added a distant emissive energy moon/orb to break up the flat skyline.
- Added 28 floating energy fragments around the arena using a single MultiMesh batch.

### Changed
- World environment now uses a sky material instead of a flat background color.
- Atmospheric fog and cyber-city silhouettes now blend into a stronger layered horizon.

### Graphics
- The arena gains vertical depth and a more recognizable anime sci-fi atmosphere without adding clutter to the combat center.

### Optimization
- Floating fragments are rendered as one MultiMesh draw path.
- LOW graphics preset hides the floating fragment batch automatically.
- Distant moon is unshaded and does not cast shadows.


## Update 21 — Ground impact VFX, haptics and Ultimate lighting pulse

### Added
- Added pooled ground shockwaves for heavy impacts and Ultimate activation.
- Added pooled stylized dash dust with density tied to LOW / MEDIUM / HIGH.
- Added short Android haptic feedback for landed impacts and Ultimate startup.
- Added a fighter-colored Ultimate lighting pulse using the existing arena fill/key lights and WorldEnvironment.

### Changed
- Fighter-specific dual-slash, arcane, cleave and plasma effects are preserved and now layer with ground-contact feedback.
- SFX hooks now recognize all fighter-specific attack VFX profiles rather than only the legacy generic slash.
- Heavy attacks combine animation, weapon trail, impact burst, shockwave, hit-stop, camera impulse and haptics.

### Graphics
- Ultimate startup now influences arena lighting in addition to aura, sky backdrop and cinematic camera motion.
- Dash movement has a lightweight ground-contact dust layer under the existing energy streak.

### Optimization
- Shockwaves and dust reuse the existing 24-slot VFX pool.
- LOW reduces both spark rays and dust fragments.
- No new realtime light nodes are spawned during combat; the Ultimate pulse reuses existing lights.

## Update 22 — v0.3.0 release packaging

### Changed
- Android `versionCode` is now 3.
- Android `versionName` is now 0.3.0.
- README now reflects the current Godot 4.7.2 architecture and visual-polish feature set.
- Legacy `UPDATE_LOG.txt` has been synchronized with the v0.3.0 milestone.

### Fixed
- Release metadata no longer identifies new builds as the original 0.1.0 prototype.


## Update 23 — Fighter-specific projectile identities

### Added
- Added four distinct projectile behavior profiles driven by fighter variant.
- Succubus Assassin fires a small fast homing orb with lighter knockback.
- Arcane Mage fires a larger slower arcane sphere with stronger homing presence and heavier hit reaction.
- Templar Knight fires a long heavy energy lance with the strongest projectile knockback and guard pressure.
- Cyber Bunny fires a very fast compact plasma bolt tuned for quick ranged pressure.
- Added three prebuilt energy trail segments to every projectile.

### Changed
- Projectile speed, lifetime, homing, collision radius, light radius, hitstun, launch, block damage and impact strength now reinforce each fighter archetype.
- Projectile visuals align to flight direction so lance/plasma silhouettes and tail segments read correctly in motion.
- Mage keeps the layered dual-orbit presentation while other fighters use lighter ring treatments.

### Graphics
- Ranged attacks now differ by shape and motion instead of color alone.
- Projectile pulse/spin rates are variant-specific.

### Optimization
- Trail segments are created once with the projectile and reused for its full lifetime.
- CI smoke validation now checks style propagation and the prebuilt projectile trail for all four variants.


## Update 24 — Fighter-specific skill mechanics

### Added
- Arcane Mage Rune Barrage now fires three individually simulated homing projectiles instead of sharing a generic melee hit.
- Arcane Mage Rift Step now repositions away/sideways with invulnerability and arcane departure/arrival feedback.
- Templar Knight Judgement Step now closes distance into a heavier armored strike.
- Cyber Bunny Flash Shift now performs a fast side reposition with brief invulnerability into a rapid attack.
- Succubus Shadow Step keeps an aggressive behind-target teleport but gains cleaner invulnerability and dash feedback.

### Changed
- Skill 3 behavior is now separately tuned for Rending Rush, Rune Barrage, Guard Breaker and Pulse Combo.
- Skill 4 timing/range/guard pressure is now separately tuned for Wing Burst, Meteor Ring, Crimson Smite and Overdrive Burst.
- Templar Guard Breaker and Crimson Smite apply substantially higher block pressure.
- Cyber Bunny skill timings favor short startup/recovery while Templar finishers favor weight and guard damage.

### Gameplay
- Fighter archetypes now differ in movement utility, ranged pressure, defensive pressure and burst timing rather than only damage values/VFX.
- Root motion remains disabled; all repositioning stays gameplay-code-driven for responsive touch controls.

### Optimization
- Mage barrage reuses the existing projectile implementation and pooled combat VFX.
- No new per-frame systems were added.


## Update 25 — Character Select presentation and mobile cooldown buttons

### Added
- Added a slowly rotating live 3D fighter preview presentation.
- Added an emissive fighter-colored preview platform with eight rotating accent markers.
- Preview key/rim lights now inherit the currently previewed fighter's color identity.
- Added direct cooldown text to S1–S4 mobile buttons.
- Added LOW-energy state directly on skill buttons.
- Added pulsing ULT READY state and live Ultimate percentage directly on the Ultimate button.

### Changed
- Character Select preview now reads as a deliberate fighting-game presentation instead of a static viewport.
- Mobile combat buttons provide actionable state without requiring the player to read the top skill strip.

### UI
- Skill buttons dim while cooling down and show remaining seconds.
- Ready buttons restore full contrast; energy-starved skills show LOW.
- Ultimate button pulses only when the meter is actually ready.

### Optimization
- Preview platform uses simple unshaded geometry and is disabled together with the preview viewport when combat begins.
- Button state updates reuse existing Button nodes; no UI nodes are created during combat.
- CI now verifies preview platform and mobile skill/Ultimate controls exist.


## Update 26 — Original pooled combat audio

### Added
- Added six original procedurally generated combat SFX: swing, impact, dash, energy, parry and Ultimate.
- Added a 10-voice pooled AudioStreamPlayer3D manager for spatial combat sound playback.
- Connected the existing SFX cue hooks to actual runtime audio.
- Added deterministic repository-side SFX generation during Android CI before Godot import/export.

### Changed
- Combat impact stack now includes real audio in addition to animation, fighter-specific VFX, hit-stop, camera impulse and Android haptics.
- Audio cues use per-category volume/pitch tuning so Ultimate/parry/impact read more strongly than movement whooshes.

### Audio
- All generated WAV files are original procedural synthesis created by `tools/generate_sfx.py`; no copyrighted external audio is used.
- Mono 22.05 kHz PCM keeps spatial playback and APK size lightweight.

### Optimization
- Ten AudioStreamPlayer3D nodes are created once and reused.
- No AudioStreamPlayer nodes are instantiated or destroyed during combat.
- CI smoke validation verifies the audio manager and all six generated cues are available before APK publication.


## Update 27 — v0.3.1 release packaging

### Changed
- Android `versionCode` is now 4.
- Android `versionName` is now 0.3.1.
- README now identifies the current stable build as Combat Identity / Audio / UI Polish.
- Legacy `UPDATE_LOG.txt` has been synchronized with the v0.3.1 milestone.

### Added
- Release summary now includes fighter-specific projectiles/skills, direct mobile cooldown states and original pooled 3D combat audio.

### Fixed
- Release metadata now matches the latest validated gameplay/visual revision instead of v0.3.0.


## Update 28 — Heavy hit knockdown and get-up reactions

### Added
- Added a dedicated heavy-hit knockdown state driven by imported `Lie_Down` / `Lie_StandUp` animation clips.
- Strong attacks, large launch values and Ultimate hits can now transition through airborne impact → ground knockdown → get-up.
- Added a short invulnerability window during the get-up phase to prevent unavoidable wake-up loops.
- Added a small pooled ground-dust cue when an airborne fighter lands into knockdown.

### Changed
- Light/medium hits keep fast alternating `Hit_A` / `Hit_B` reactions for responsiveness.
- Heavy reactions cancel the victim's current attack and temporarily lock normal movement/AI.
- Knockdown horizontal velocity decays smoothly instead of stopping instantly.

### Animation
- Heavy impact reactions now have a visible recovery arc instead of snapping directly from hit-stun back to idle.
- Death overrides and clears any active knockdown state.

### Gameplay
- Ultimate/heavy attacks gain more visual and mechanical weight without extending every normal hit.
- Wake-up protection is brief and only active during the stand-up transition.

### Optimization
- Knockdown uses existing imported clips and fighter state variables; no additional scene nodes are created.
- CI smoke validation now explicitly checks knockdown entry and recovery.


## Update 29 — Cinematic KO and victory flow

### Added
- Added a dedicated short KO camera state with low-angle winner/loser framing.
- Added imported `Cheer` victory animation for the surviving fighter.
- Added delayed animated result reveal on device after the KO camera beat.
- Added stronger KO haptic feedback on Android.

### Changed
- Both fighters are locked when the match ends so residual AI/input cannot move during the result beat.
- KO now cancels any active Ultimate camera and transitions into its own framing.
- Result text now eases from a slightly enlarged transparent state instead of appearing instantly.
- Rematch clears victory presentation before spawning the next round.

### Animation
- Winner remains in a victory pose while the defeated fighter stays in its death state.
- Normal movement animation sync no longer overrides the Cheer clip during the KO presentation.

### Camera
- KO camera uses collision-safe interpolation, fighter-dependent side selection and a restrained FOV transition.

### Optimization
- KO presentation reuses the existing camera and HUD nodes.
- Headless CI skips the presentation delay while still validating the victory-pose state and result screen.

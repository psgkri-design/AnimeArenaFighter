# Third-Party Asset Licenses

All third-party content used by Anime Arena Fighter must have a clear redistribution-compatible license. Protected franchise assets and ripped game content are not permitted.

## KayKit Character Pack: Adventures 1.0

- **Author:** Kay Lousberg / KayKit
- **Source:** https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- **License:** Creative Commons Zero v1.0 Universal (CC0 1.0)
- **Files used by Android CI:** Rogue_Hooded.glb, Mage.glb, Knight.glb, Rogue.glb
- **Used for:** Rigged base characters for the four playable fighters. The game adds fighter-specific colors, accessories, weapons/effects and gameplay identity.
- **License copy in build workspace:** assets/kaykit/KAYKIT_LICENSE.txt

## Quaternius Universal Base Characters / Universal Animation Library

- **Author:** Quaternius
- **Source:** https://quaternius.com/packs/universalbasecharacters.html and https://quaternius.com/packs/universalanimationlibrary.html
- **License:** The referenced free Standard releases are documented by their release pages/repositories as CC0.
- **Current status:** Evaluated as a higher-detail future character/animation source; not yet required at runtime in this update.
- **Planned use:** Humanoid base bodies and retargetable locomotion/combat animation upgrades after compatibility validation.

## Project rule

Do not add models, textures, animation clips, audio, logos or other assets extracted from commercial games or protected anime franchises. Visual references may inform quality and style only.


### KayKit weapon/accessory meshes used

The same KayKit Character Pack: Adventures 1.0 CC0 license also covers the weapon assets integrated by Android CI:

- `dagger.gltf` + `dagger.bin` — Succubus Assassin dual daggers.
- `staff.gltf` + `staff.bin` — Arcane Mage staff.
- `sword_2handed_color.gltf` + `sword_2handed_color.bin` — Templar Knight heavy sword.
- `sword_1handed.gltf` + `sword_1handed.bin` — Cyber Bunny blade.
- Shared KayKit texture atlases: `rogue_texture.png`, `mage_texture.png`, `knight_texture.png`.

These are fetched from the pack's `Assets/gltf` directory during CI and attached to the rig's authored `handslot.l/r` bones.

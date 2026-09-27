extends RefCounted

const FIGHTERS := [
    {
        "name": "SUCCUBUS ASSASSIN",
        "short": "SA",
        "role": "Rushdown / Air",
        "description": "Fast demon fighter built around pressure, evasive movement and close-range burst.",
        "color": Color(0.72, 0.12, 0.48),
        "accent": Color(0.16, 0.03, 0.18),
        "health": 880.0,
        "stamina": 125.0,
        "move_speed": 8.7,
        "power": 0.98,
        "defense": 0.88,
        "range": 2,
        "speed": 5,
        "power_stat": 3,
        "defense_stat": 2,
        "skills": ["Abyss Orb", "Shadow Step", "Rending Rush", "Wing Burst"]
    },
    {
        "name": "ARCANE MAGE",
        "short": "AM",
        "role": "Zoner / Control",
        "description": "Keeps distance with magic projectiles, teleports and wide area attacks.",
        "color": Color(0.55, 0.20, 0.72),
        "accent": Color(0.92, 0.35, 0.18),
        "health": 820.0,
        "stamina": 100.0,
        "move_speed": 7.0,
        "power": 1.02,
        "defense": 0.82,
        "range": 5,
        "speed": 3,
        "power_stat": 4,
        "defense_stat": 2,
        "skills": ["Arc Bolt", "Rift Step", "Rune Barrage", "Meteor Ring"]
    },
    {
        "name": "TEMPLAR KNIGHT",
        "short": "TK",
        "role": "Tank / Power",
        "description": "Heavy frontline fighter with strong guard pressure, armor and brutal finishers.",
        "color": Color(0.86, 0.80, 0.66),
        "accent": Color(0.60, 0.06, 0.08),
        "health": 1250.0,
        "stamina": 108.0,
        "move_speed": 6.2,
        "power": 1.20,
        "defense": 1.22,
        "range": 3,
        "speed": 2,
        "power_stat": 5,
        "defense_stat": 5,
        "skills": ["Holy Lance", "Judgement Step", "Guard Breaker", "Crimson Smite"]
    },
    {
        "name": "CYBER BUNNY",
        "short": "CB",
        "role": "Mobility / Burst",
        "description": "High-tech agile fighter with fast dashes, plasma attacks and rapid repositioning.",
        "color": Color(0.88, 0.91, 0.96),
        "accent": Color(1.0, 0.34, 0.04),
        "health": 940.0,
        "stamina": 130.0,
        "move_speed": 8.3,
        "power": 1.00,
        "defense": 0.96,
        "range": 4,
        "speed": 5,
        "power_stat": 3,
        "defense_stat": 3,
        "skills": ["Plasma Shot", "Flash Shift", "Pulse Combo", "Overdrive Burst"]
    }
]

static func count() -> int:
    return FIGHTERS.size()

static func get_data(index: int) -> Dictionary:
    return FIGHTERS[clampi(index, 0, FIGHTERS.size() - 1)]

# Stage layout tables taken from the original SWF display lists.
extends RefCounted

# Alpha of the intro twinkle square (sprite 130) for its first 30 frames.
const TWINKLE := [
	0.0,
	0.0,
	0.01,
	0.03,
	0.06,
	0.1,
	0.15,
	0.2,
	0.26,
	0.33,
	0.41,
	0.49,
	0.59,
	0.69,
	0.8,
	0.8,
	0.78,
	0.77,
	0.74,
	0.71,
	0.67,
	0.62,
	0.57,
	0.51,
	0.44,
	0.37,
	0.29,
	0.2,
	0.1,
	0.0,
]

# Intro squares (sprite 131 x16) start positions on frame 8 of the root timeline.
const SQUARE_POS := [
	Vector2(275.7, 196.95),
	Vector2(270.0, 201.8),
	Vector2(281.1, 202.25),
	Vector2(273.2, 204.65),
	Vector2(272.8, 199.15),
	Vector2(278.7, 199.15),
	Vector2(279.25, 204.85),
	Vector2(276.25, 206.35),
	Vector2(275.9, 182.9),
	Vector2(270.2, 187.75),
	Vector2(281.3, 188.2),
	Vector2(273.4, 190.6),
	Vector2(273.0, 185.1),
	Vector2(278.9, 185.1),
	Vector2(279.45, 190.8),
	Vector2(276.45, 192.3),
]

# Background plants: [sheet, x, y, xscale, yscale, alpha]. Depths 2-12.
const BACK_PLANTS := [
	["plant_a", 400.6, 354.55, -0.25, 0.25, 64.0 / 256.0],
	["plant_a", 233.55, 342.55, 0.35, 0.35, 38.0 / 256.0],
	["plant_b", 41.85, 325.3, -0.75, 0.75, 38.0 / 256.0],
	["plant_a", 171.6, 305.55, -0.65, 0.65, 102.0 / 256.0],
	["plant_b", 290.6, 322.65, 0.75, 0.75, 18.0 / 256.0],
	["plant_b", 446.6, 317.6, -0.65, 0.65, 10.0 / 256.0],
]

# Foreground plants, only during play. Depths 50-54.
const FRONT_PLANTS := [
	["plant_b", 120.45, 375.55, 0.5, 0.5, 1.0],
	["plant_b", 352.35, 391.55, -0.25, 0.25, 1.0],
	["plant_a", 501.1, 352.6, 0.75, 0.5, 1.0],
]

const LETTERS := [
	Vector2(-174.1, 0.0),
	Vector2(-109.5, -1.55),
	Vector2(-61.2, 0.05),
	Vector2(-9.6, -1.55),
	Vector2(47.45, 1.6),
	Vector2(109.45, 2.45),
	Vector2(166.85, 0.05),
]

# pfishbone1..17 positions (depths 58-106).
const PBONE_POS := [
	Vector2(16.75, 10.45),
	Vector2(48.75, 10.45),
	Vector2(81.25, 10.45),
	Vector2(112.45, 10.85),
	Vector2(144.45, 10.85),
	Vector2(176.45, 10.9),
	Vector2(208.65, 10.9),
	Vector2(239.85, 11.3),
	Vector2(271.85, 11.3),
	Vector2(303.8, 11.25),
	Vector2(336.3, 11.25),
	Vector2(367.5, 11.65),
	Vector2(399.5, 11.65),
	Vector2(431.5, 11.7),
	Vector2(463.7, 11.7),
	Vector2(494.9, 12.1),
	Vector2(526.9, 12.1),
]

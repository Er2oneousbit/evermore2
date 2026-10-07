# =============================================================================
# combat_arena.gd  -  Test map for combat (not part of the story)
# -----------------------------------------------------------------------------
# WHAT:  A fenced field with a few giant rats to fight: the sandbox for the
#        combat milestone (the swing, the auto charge, enemies, hit feedback,
#        Normal vs Hard). Tests run here so the story maps stay clean.
# RUN:   godot --path . res://realms/test/combat_arena_hd.tscn   (add -- --hard)
#
# LEGEND: . grass  # wood fence  K kid  D dog  r giant rat
#         T oak  R big rock  o small rock  B bush  v tall grass
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

const LAYOUT: Array[String] = [
	"##############################",
	"#....T.........vv.......T....#",
	"#..........r.................#",
	"#..v..............R......r...#",
	"#.........o..................#",
	"#...r.........B..............#",
	"#..................v.........#",
	"#........T.........o....r....#",
	"#..o.........................#",
	"#.............r..............#",
	"#.....B..............T.......#",
	"#..v.........................#",
	"#............K.D.............#",
	"#...T................vv...B..#",
	"##############################",
]

const REALM_NAME_KEY := "realm_combat_arena"
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"R": ["rock_big"],
	"o": ["rock_small_a", "rock_small_b"],
	"B": ["bush_round_a", "bush_round_b"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "grass_clump_a"],
}
const ENEMIES_BY_CHAR := {"r": "rat"}

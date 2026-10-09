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
#         : dirt  _ the path south, back to the test yard (EXITS)
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
	"#...T.........::.....vv...B..#",
	"##############__##############",
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
## The path back to the test yard (realms/_shared/ascii_realm.gd MAP EXITS).
const EXITS := {"_": {"to": "res://realms/big_yard/yard_hd.tscn", "entry": "from_arena"}}
const ENTRIES := {"from_yard": {"cell": Vector2i(14, 11), "facing": Vector2.UP}}
## The yard hands out the same kit: once between them.
const START_ITEMS_FLAG := "demo.start_items"
const MUSIC := "arena"
## A kit of demo gear to try in the ring menu (I / gamepad Y).
const START_ITEMS := {"rusty_sword": 1, "bike_helmet": 1, "hoodie": 1, "hiking_boots": 1,
		"garden_gloves": 1, "studded_collar": 1, "apple": 3, "soda": 1, "wild_carrot": 3}
## The first formula, to try in the Alchemy ring.
const START_FORMULAS := ["heal"]

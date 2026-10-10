# =============================================================================
# combat_arena.gd  -  Test map for combat (not part of the story)
# -----------------------------------------------------------------------------
# WHAT:  A big fenced countryside (100 x 56 tiles, about 6x what a 3440x1440
#        screen shows) to fight in: open fields, oak groves, rocks, three ponds,
#        dirt roads, a fenced pen, fence lanes and bush hedges. It is the sandbox
#        for combat (the swing, the auto charge, enemies, hit feedback, Normal
#        vs Hard) and, since the yard lost its enemies, the day/night demo:
#        giant rats sleep where they stand (r), rats on the day schedule come
#        and go through burrows (x), and bats hang in the oaks by day and fly
#        by night. Most of them start far off screen and wake as you approach.
#        Tests run here so the story maps stay clean.
# RUN:   godot --path . res://realms/test/combat_arena_hd.tscn   (add -- --hard)
#
# LEGEND: . grass  # wood fence  K kid  D dog  x giant rat (day; holes at dusk)
#         z skeleton (night; rises from the ground)  bats roost in oaks
#         T / t oak  R big rock  o small rock  B bush (hedges)  s shrub
#         v tall grass  ~ pond (solid)  : dirt road
#         _ the road south, back to the test yard (EXITS)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

const LAYOUT: Array[String] = [
	"####################################################################################################",
	"#..................................................T...............................................#",
	"#.................T....vvvT.................vvv......T......T......................................#",
	"#.......................T....................v.....................................................#",
	"#.................T..T...................o............vvvT.T.T..###############################....#",
	"#............T.............................vvv.........v......o.#.............................#....#",
	"#....t...T..s.....t.........................v................T..#.............................#s...#",
	"#........................................................T......#...............z.............#....#",
	"#.vvvT...t...T....vvv.......................vvv..::.............#.............................#....#",
	"#..v.s.........s...v........................sv...::..............s..........x.......s.........#....#",
	"#...T.t.....t.::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::........#.s..#",
	"#.............:..............s...................::...o.........#.....s..............:........#....#",
	"#.........T...:s....s.....o..s...s......z.s...s..::.............#.....s..............:.vvv....#....#",
	"#....s........:............t................T....::..........z..#....................:..v.....#....#",
	"#.............:.z.......s........t.......R..x....::.............#....................:...vvv..#....#",
	"#.............:.........................s........::......x....x.##############...####:#########....#",
	"#...........x.:.....x.......................T....::..........s.......................:s............#",
	"#.............:.............~....................::...............z..................:.............#",
	"#..T....z.....:.......~~~~~~~~~~~~~......s.......::.BBBBBBBB.........................:....vvv......#",
	"#...vvv....x..:..s..~~~~~~~~~~~~~~~~~.....s......::......s...................z....s..:.....v.......#",
	"#.T.TvT.......:....~~~~~~~~~~~~~~~~~~~...........::.....................~.......T.T.s:.............#",
	"#.............:....~~~~~~~~~~~~~~~~~~~...........::.................~~~~~~~~~...sx...:.....vvv.....#",
	"#......T......:s..~~~~~~~~~~~~~~~~~~~~~..........::..s............~~~~~~~~~~~~~...T.s:s.....v......#",
	"#..........z..:....~~~~~~~~~~~~~~~~~~~...........::...............~~~~~~~~~~~~~......:.......s.....#",
	"#.o...........:....~~~~~~~~~~~~~~~~~~~..########.::..............~~~~~~~~~~~~~~~.....:....s........#",
	"#.s.......s...:.....~~~~~~~~~~~~~~~~~...#........::...............~~~~~~~~~~~~~..vvv.:.z...........#",
	"#.............:.......~~~~~~~~~~~~~.....#........::..T.T..T.......~~~~~~~~~~~~~...v..:........z....#",
	"#......o......:.............~...........#........::..s..............~~~~~~~~~......x.:s..........o.#",
	"#...###..####.:.........................#.....s..::s..T...T.T...........~......vvv...:.vvvT...t....#",
	"#...........#.:.......z....v.v...................::............o................v....:..v..........#",
	"#...........#.:.............v....................::.......T...T......................:s.T.....x....#",
	"#...........#.:...x..........vvv........#......o.::..................................:...s....T....#",
	"#.............:.BBBBBBBBB.BBBBBBBBB.....#.....s..::......t...vvv.....................:.T.T..T......#",
	"#.............:.........................#........::...........########...########....:s............#",
	"#...........#.:.......R...x........t..t.#........::......s.vvv.......................:..o.....vvv..#",
	"#...........#.:..................................::.........v.........vvvs...........:........sv...#",
	"#...R....z..#.:....xs.........z...T...TR..s......::.x....z.............v.........z...:.............#",
	"#...s......vvv:.....s...vvv........vvv...........::.........................vvv......:.............#",
	"#....x..:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::......#",
	"#.......:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::......#",
	"#.........x................vvv...................::..........................x...x.................#",
	"#....t.....s..........z.....v.......vv#..........::..........#................s....................#",
	"#..o..R.......z..............vvv.....v#..........::.........s#...........z................T.T......#",
	"#.............................v.......#.......vvv::..........#..................~.....T.....s......#",
	"#...t.t.T...T...vvv.########..#########........v.::..........#.....s.........~~~~~~~.......T.......#",
	"#................v.......T............#..........::..........#..vvvvvv......~~~~~~~~~..T...........#",
	"#...T....T.t.........x..........T.....#..........::......x...#...v..o......~~~~~~~~~~~....T........#",
	"#.........................t.z....x...............::.....v...................~~~~~~~~~..............#",
	"#................z..o...........t..........s.....K:D.z.................R.....~~~~~~~.......z.......#",
	"#.........................o..T....t...#..........::.......s..#..................~............R.....#",
	"#....vvv..............................#..........::..........#.........................x...........#",
	"#..vvvv...................T......t....#..........::..........#...s...vvv...............vvv.........#",
	"#...BBBBBBBBBB.BBBBBBBBBB.BBBBB.......#.........R::..........#....BBBBBBB.BBBBBBB.BBBBBBB.BBB......#",
	"#............s..............v.........#..........::..........#......o...o..........................#",
	"#................................................::................................................#",
	"#################################################__#################################################",
]

const REALM_NAME_KEY := "realm_combat_arena"
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"t": ["oak_light"],
	"R": ["rock_big"],
	"o": ["rock_small_a", "rock_small_b"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "grass_clump_a"],
}
## Day and night (owner, 2026-10-09): giant rats are the DAY enemies ("x": out
## by day, into their hole at dusk, back at dawn); skeletons are the NIGHT ones
## ("z": they rise out of the ground at dusk, staggered, and sink back at
## dawn). Bats fly out of the oaks at dusk and back into them at dawn.
const ENEMIES_BY_CHAR := {"x": "rat", "z": "skeleton"}
## The clock runs on its own here, so day and night happen in the arena.
const CLOCK_MODE := "free"
## Enemies follow the clock (systems/enemies/day_night.gd): bats spend the day
## unseen in the oaks and fly by night. Each "x" rat's own cell is its burrow,
## plus the holes under a few hedge bushes.
const ENEMY_CLOCK := "follow_clock"
const ENEMY_ROOSTS := [
	{"enemy": "bat", "cell": Vector2i(82, 22)},
	{"enemy": "bat", "cell": Vector2i(9, 46)},
	{"enemy": "bat", "cell": Vector2i(10, 12)},
	{"enemy": "bat", "cell": Vector2i(58, 30)},
	{"enemy": "bat", "cell": Vector2i(18, 2)},
	{"enemy": "bat", "cell": Vector2i(33, 14)},
	{"enemy": "bat", "cell": Vector2i(53, 2)},
	{"enemy": "bat", "cell": Vector2i(2, 20)},
	{"enemy": "bat", "cell": Vector2i(90, 46)},
]
const ENEMY_EXITS := [
	{"cell": Vector2i(43, 50), "kind": "burrow"},  # two by the entrance road
	{"cell": Vector2i(57, 50), "kind": "burrow"},
	{"cell": Vector2i(80, 52), "kind": "burrow"},
	{"cell": Vector2i(30, 52), "kind": "burrow"},
	{"cell": Vector2i(76, 52), "kind": "burrow"},
	{"cell": Vector2i(83, 52), "kind": "burrow"},
	{"cell": Vector2i(27, 52), "kind": "burrow"},
	{"cell": Vector2i(18, 32), "kind": "burrow"},
]
## The path back to the test yard (realms/_shared/ascii_realm.gd MAP EXITS).
const EXITS := {"_": {"to": "res://realms/big_yard/yard_hd.tscn", "entry": "from_arena"}}
const ENTRIES := {"from_yard": {"cell": Vector2i(49, 52), "facing": Vector2.UP}}
## The yard hands out the same kit: once between them.
const START_ITEMS_FLAG := "demo.start_items"
const MUSIC := "arena"
## A kit of demo gear to try in the ring menu (I / gamepad Y).
const START_ITEMS := {"rusty_sword": 1, "bike_helmet": 1, "hoodie": 1, "hiking_boots": 1,
		"garden_gloves": 1, "studded_collar": 1, "apple": 3, "soda": 1, "wild_carrot": 3}
## The first formula, to try in the Alchemy ring.
const START_FORMULAS := ["heal"]

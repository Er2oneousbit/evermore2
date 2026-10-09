# =============================================================================
# prototype_yard.gd  -  The test yard: a tech demo map (real LPC Revised art)
# -----------------------------------------------------------------------------
# WHAT:  A backyard built from the ASCII LAYOUT below by AsciiRealm
#        (realms/_shared/ascii_realm.gd): autotiled grass, dirt and a koi pond,
#        wood fences, trees, roses, rocks, decals, and woods past the edges.
#        Not part of the story (its realm was scrapped); it's the map the
#        follow, aspect and HD-2D tests run on, and a sandbox for art and tech.
#        East through the garden gate: a small street with two shops (the
#        corner store closes at night, the all-night stand never does) and two
#        rats in the far corner to try night fights on. The clock runs free
#        here (24 minutes a day; F7 stops it, F9 speeds it up).
#
# LEGEND (one character = one 32x32 tile)
#   .  grass               :  dirt (paths, flowerbeds)   ~  pond (solid)
#   #  wood fence (solid)  K  kid spawn                  D  dog spawn
#   T  oak                 t  light-green oak            B  round bush (solid)
#   s  shrub               l  leafy plant                v  tall grass
#   R  big rock (solid)    r  small rock (solid)         *  rose bush (on dirt)
#   f  flower              m  mushrooms                  w  wildflower patch
#   ,  bare grass (no decal: under and above the stalls)
#   A  corner store stall  N  all-night stall            1 / 2  their keepers
#   x  giant rat
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

const LAYOUT: Array[String] = [
	"######################################################",
	"#...vv....w...t.................vv.....#.t......::...#",
	"#.T.................wr..~~~~~~~....T...#....,,,.::..T#",
	"#v...............m.....~~~~~~~~~~......#..s.,,,.::...#",
	"#......w....s......T..~~~~~~~~~~~~.....#....,,,.::.v.#",
	"#..K............w......~~~~~~~~~~..BB..#....,A,.::...#",
	"#...D....................~~~~~~........#B....1..::..s#",
	"#....::::::::::::::::.......w..........#........::...#",
	"#B..vv.:..ll....B...:...w......l.....t.#.v...w..::.t.#",
	"#......:............:.....vvT..........#....,,,.::...#",
	"#######:.##########.:.T.......w...s.r..#....,,,.::...#",
	"#..........#......#.:..................#....,N,.::.B.#",
	"#...l......#...t..#.:.....::::::::::::.#..l..2..::...#",
	"#.t........#..w...#.:v....:*:*:*:*:*::.#........::..v#",
	"#.................#.:.....::::::::::::v#.t......::...#",
	"##############....#.:..t..:*:*:*:*:*::.#....w...::.s.#",
	"#.................#.:.....::::::::::::.#........::...#",
	"#....s......r.....#.:...............w...........::...#",
	"#..w................:.....f..f..f..f...::::::::::::..#",
	"#.......vv..........:................t..........::...#",
	"#.....m..T.....r..#.:::::::......T.....#..s.....::.x.#",
	"#..R.........s....#......B..vv.w.......#...T....::..x#",
	"#.........w.......#...........m...vv...#.....v..::.r.#",
	"######################################################",
]

const FENCE_CHAR := "#"
const REALM_NAME_KEY := "realm_test_yard"
const MUSIC_SET := "outdoor"  # the day and night tracks follow the clock
## The clock runs on its own here (a tech demo of the day going by).
const CLOCK_MODE := "free"
## The rats ignore the clock (the hook for night-only enemies, unused yet).
const ENEMY_CLOCK := "unchanged"
const DIALOGUE := "res://data/dialogue/yard.dlg"
## Terrain under each character; anything not listed is grass.
const TERRAIN_BY_CHAR := {":": "Dirt", "*": "Dirt", "~": "Shallow Water", ",": "Grass"}
## Which props each character can place (picked deterministically per cell).
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"t": ["oak_light"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"l": ["leafy_a", "leafy_b", "leafy_c", "leafy_d"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "tall_grass_d", "grass_clump_a", "grass_clump_b"],
	"R": ["rock_big"],
	"A": ["stall_corner"],
	"N": ["stall_allnight"],
	"r": ["rock_small_a", "rock_small_b", "rock_wide"],
	"*": ["rose_red", "rose_pink", "rose_white", "rose_yellow", "rose_purple", "rose_peach"],
	"f": ["flower_red", "flower_yellow", "flower_blue", "flower_white", "flower_orange", "flower_purple", "flower_pink"],
	"m": ["mushroom_red", "mushroom_cluster_a", "mushroom_cluster_b", "mushroom_brown"],
	"w": ["wildflowers_00", "wildflowers_01", "wildflowers_04", "wildflowers_05", "wildflowers_06",
			"wildflowers_08", "wildflowers_12", "wildflowers_13", "wildflowers_16", "wildflowers_17"],
}
## Stalls sit exactly on their cell and keep their signs unmirrored.
const BIG_PROP_CHARS := "TtRAN"
const NO_FLIP_CHARS := "AN"
## The two shops (systems/shops/shop.gd). The keeper stands on the digit, the
## stall is the letter just north of it.
const SHOPS_BY_CHAR := {
	"1": {"id": "corner_store", "keeper": "GROCER", "rule": "follow_clock", "item": "apple",
			"greet": "shop_corner", "again": "shop_corner_again", "closed": "shop_corner_closed"},
	"2": {"id": "all_night", "keeper": "VENDOR", "rule": "always_open", "item": "soda",
			"greet": "shop_allnight", "again": "shop_allnight_again"},
}
const ENEMIES_BY_CHAR := {"x": "rat"}
## Hidden items (the dog sniffs them out). Demo items for now.
const HIDDEN_ITEMS := [
	{"cell": Vector2i(9, 3), "kind": "buried", "item": "old_key"},
	{"cell": Vector2i(16, 8), "kind": "tucked", "item": "shiny_stone"},
	{"cell": Vector2i(10, 11), "kind": "secret", "item": "coin_pouch"},
	{"cell": Vector2i(36, 10), "kind": "tucked", "item": "torn_map"},
	{"cell": Vector2i(30, 14), "kind": "buried", "item": "wild_carrot", "count": 2},
]
## A kit of demo gear to try in the ring menu (I / gamepad Y).
const START_ITEMS := {"rusty_sword": 1, "bike_helmet": 1, "hoodie": 1, "hiking_boots": 1,
		"garden_gloves": 1, "studded_collar": 1, "apple": 3, "soda": 1, "wild_carrot": 3}
## The first formula, to try in the Alchemy ring.
const START_FORMULAS := ["heal"]
## Kept as named constants because tests read them.
const APRON_TILES := 14

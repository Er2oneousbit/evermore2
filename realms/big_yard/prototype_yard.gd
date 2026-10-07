# =============================================================================
# prototype_yard.gd  -  The test yard: a tech demo map (real LPC Revised art)
# -----------------------------------------------------------------------------
# WHAT:  A backyard built from the ASCII LAYOUT below by AsciiRealm
#        (realms/_shared/ascii_realm.gd): autotiled grass, dirt and a koi pond,
#        wood fences, trees, roses, rocks, decals, and woods past the edges.
#        Not part of the story (its realm was scrapped); it's the map the
#        follow, aspect and HD-2D tests run on, and a sandbox for art and tech.
#
# LEGEND (one character = one 32x32 tile)
#   .  grass               :  dirt (paths, flowerbeds)   ~  pond (solid)
#   #  wood fence (solid)  K  kid spawn                  D  dog spawn
#   T  oak                 t  light-green oak            B  round bush (solid)
#   s  shrub               l  leafy plant                v  tall grass
#   R  big rock (solid)    r  small rock (solid)         *  rose bush (on dirt)
#   f  flower              m  mushrooms                  w  wildflower patch
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

const LAYOUT: Array[String] = [
	"########################################",
	"#...vv....w...t.................vv.....#",
	"#.T.................wr..~~~~~~~....T...#",
	"#v...............m.....~~~~~~~~~~......#",
	"#......w....s......T..~~~~~~~~~~~~.....#",
	"#..K............w......~~~~~~~~~~..BB..#",
	"#...D....................~~~~~~........#",
	"#....::::::::::::::::.......w..........#",
	"#B..vv.:..ll....B...:...w......l.....t.#",
	"#......:............:.....vvT..........#",
	"#######:.##########.:.T.......w...s.r..#",
	"#..........#......#.:..................#",
	"#...l......#...t..#.:.....::::::::::::.#",
	"#.t........#..w...#.:v....:*:*:*:*:*::.#",
	"#.................#.:.....::::::::::::v#",
	"##############....#.:..t..:*:*:*:*:*::.#",
	"#.................#.:.....::::::::::::.#",
	"#....s......r.....#.:...............w..#",
	"#..w................:.....f..f..f..f...#",
	"#.......vv..........:................t.#",
	"#.....m..T.....r..#.:::::::......T.....#",
	"#..R.........s....#......B..vv.w.......#",
	"#.........w.......#...........m...vv...#",
	"########################################",
]

const FENCE_CHAR := "#"
const REALM_NAME_KEY := "realm_test_yard"
## Terrain under each character; anything not listed is grass.
const TERRAIN_BY_CHAR := {":": "Dirt", "*": "Dirt", "~": "Shallow Water"}
## Which props each character can place (picked deterministically per cell).
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"t": ["oak_light"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"l": ["leafy_a", "leafy_b", "leafy_c", "leafy_d"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "tall_grass_d", "grass_clump_a", "grass_clump_b"],
	"R": ["rock_big"],
	"r": ["rock_small_a", "rock_small_b", "rock_wide"],
	"*": ["rose_red", "rose_pink", "rose_white", "rose_yellow", "rose_purple", "rose_peach"],
	"f": ["flower_red", "flower_yellow", "flower_blue", "flower_white", "flower_orange", "flower_purple", "flower_pink"],
	"m": ["mushroom_red", "mushroom_cluster_a", "mushroom_cluster_b", "mushroom_brown"],
	"w": ["wildflowers_00", "wildflowers_01", "wildflowers_04", "wildflowers_05", "wildflowers_06",
			"wildflowers_08", "wildflowers_12", "wildflowers_13", "wildflowers_16", "wildflowers_17"],
}
## Kept as named constants because tests read them.
const APRON_TILES := 14

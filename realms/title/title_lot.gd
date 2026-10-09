# =============================================================================
# title_lot.gd  -  The title screen's backdrop: the iron gate at night
# -----------------------------------------------------------------------------
# WHAT:  A small AsciiRealm built from the same art and layout as the prologue
#        street (realms/podunk/ruffleberg_lot.gd): the lot's iron fence with a
#        dirt path running through its gap (the gate), oaks and tall grass, the
#        road in front. Night, fireflies and fog come from the HdView night
#        preset, the crickets from the "outdoor" ambience, the theme from MUSIC.
# WHY:   The title screen wants a live HD-2D picture, not a flat image, and
#        reusing the real realm would drag in the prologue's story, NPCs and
#        HUD. TitleScreen hides the kid and dog (every realm needs them) and
#        drifts the camera. Keep the layout in step with the street if its art
#        changes.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

const LAYOUT: Array[String] = [
	"vvTvvv.vvvTvvvv.vvvvTvvv.vvvTvvvvv.vTv",
	"vvvvvvTvvvvvvvTvvvvvvvvTvvvvvvvTvvvvvv",
	".vTvvvvvvTvvvvvvvvvvvvvvvvvTvvvvvvTvv.",
	"vvvvvTvvvvvvvTvvvvvvvvvvTvvvvvvTvvvvvv",
	"vTvvvvvvTvvvvvvvvvv:vvvvvvvvvvTvvvvvTv",
	"vvvvBvvvvvvvBvvvvvv:vvvvvvvBvvvvvvvvvv",
	"vvBvvvvvBvvvvvvvvvv:vvvvvvvvvvBvvvvBvv",
	"%%%%%%%%%%%%%%%%%%%:%%%%%%%%%%%%%%%%%%",
	"#..................:.................#",
	"#....s.............:.......f.....s...#",
	"#.w................:.....w...........#",
	"#::::::::::::::::::::::::::::::::::::#",
	"#::::::::::::::::::::::::::::::::::::#",
	"#...K.D.........w............w.......#",
	"#..B.....l.....s........B.......s....#",
	"#.......w...........................B#",
	"#..T..........B.......w......T.......#",
	"######################################",
]

const REALM_NAME_KEY := "place_ruffleberg_lot"
const MUSIC := "title"
const CLOCK_MODE := "hold"
const TERRAIN_BY_CHAR := {":": "Dirt"}
const FENCES := {"#": "Wood Fence", "%": "Metal Fence"}
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "tall_grass_d", "grass_clump_a", "grass_clump_b"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"l": ["leafy_a", "leafy_b", "leafy_c", "leafy_d"],
	"w": ["wildflowers_00", "wildflowers_04", "wildflowers_08", "wildflowers_12", "wildflowers_16"],
	"f": ["flower_white", "flower_yellow", "flower_orange"],
}

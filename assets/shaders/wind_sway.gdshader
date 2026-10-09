// =============================================================================
// wind_sway.gdshader  -  Pixel-crisp wind sway for plants, trees, grass tufts
// -----------------------------------------------------------------------------
// WHAT:  Shifts each ROW of pixels sideways by a whole number of texels, more
//        at the top of the sprite than at the bottom. The base stays planted,
//        the canopy sways, and pixels never smear (no sub-pixel resampling).
// WHERE: Sprite2D props whose origin is at the base (trees, bushes, tufts).
//        Do NOT put it on a TileMapLayer: shifted rows would pull in pixels
//        from neighboring tiles in the atlas.
// SETUP: `height` = how many pixels above the origin reach full sway (the
//        sprite's visible height). Keep a couple of transparent pixels of
//        padding at the sprite's left/right edges or the sway clips there.
//        Neighbors sway out of sync automatically (phase comes from world x/y).
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type canvas_item;

// Max sideways shift at the very top, in texels.
uniform float strength : hint_range(0.0, 6.0) = 1.5;
// Sway cycles per second (roughly).
uniform float speed : hint_range(0.0, 4.0) = 0.6;
// Pixels above the origin that get the full sway (sprite height).
uniform float height = 96.0;
// Bottom fraction of the sprite that never moves (trunk/roots).
uniform float rooted : hint_range(0.0, 1.0) = 0.35;
// The sprite's region inside its atlas, in UV (x, y, w, h). Pixels shifted in
// from outside it come out transparent instead of borrowing a neighbor's art.
// Prop sets this automatically; the default means "whole texture".
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

varying float local_y;
varying vec2 world_pos;
varying vec4 vertex_color;

void vertex() {
	local_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_color = COLOR;
}

void fragment() {
	// 0 at the roots, 1 at the top, eased so the top does most of the moving.
	float h = clamp((-local_y / height - rooted) / (1.0 - rooted), 0.0, 1.0);
	// Two sine waves = a lazy breeze with the occasional gust. Phase from the
	// sprite's world position so a row of trees doesn't move in lockstep.
	float phase = world_pos.x * 0.013 + world_pos.y * 0.007;
	float t = TIME * speed * 6.2831 + phase;
	float sway = sin(t) * 0.75 + sin(t * 2.37 + 1.3) * 0.25;
	// Everything above the roots moves as one block. Scaling the shift by height
	// made the row where it rounds from 0 to 1 slide up and down the canopy as
	// the wind changed: a visible wipe (owner, 2026-10-09).
	float shift = round(sway * strength * step(0.001, h));
	vec2 uv = UV - vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0);
	float inside = step(uv_rect.x, uv.x) * step(uv.x, uv_rect.x + uv_rect.z);
	COLOR = texture(TEXTURE, uv) * vertex_color;
	COLOR.a *= inside;
}

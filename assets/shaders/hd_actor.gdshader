// =============================================================================
// hd_actor.gdshader  -  Characters (kid, dog, NPCs, enemies) in the HD-2D world
// -----------------------------------------------------------------------------
// WHAT:  The material on each actor's Sprite3D. The Sprite3D still does the
//        work of picking the frame and flipping it (its UVs already point at
//        the right frame) and passes its modulate as the vertex color (hit
//        flashes, telegraphs). This shader only changes how it's LIT:
//          - the lighting normal leans up toward the camera, like the props
//            (hd_sprite.gdshader). A plain Sprite3D's normal faces the camera,
//            and the sun shines from the top of the screen TOWARD the camera,
//            so characters were always backlit: only ambient light reached
//            them and they looked dark and muddy
//          - `lift` adds a little of the sprite's own color back as emission,
//            so a character in a tree's shadow still reads (the HD-2D look:
//            the cast is always the clearest thing on screen)
//          - `scent` (per instance, 0..1) makes an enemy glow warm while the
//            dog smells it at night (Enemy.scent); 0 for everyone else
// WHO SETS IT: systems/hd2d/hd_view.gd (one material per sheet; lift per time
//        of day from its PRESETS; scent per sprite every frame).
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_nearest;
uniform float lift : hint_range(0.0, 1.0) = 0.1;
uniform vec3 scent_color : source_color = vec3(1.0, 0.86, 0.5);
instance uniform float scent : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(tex, UV) * COLOR;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	// Kept modest: a sprite brighter than its surroundings blooms in HD-2D.
	EMISSION = c.rgb * (lift + 0.5 * scent) + scent_color * (0.18 * scent);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(0.0, 0.8, 0.6)), 0.0)).xyz);
}

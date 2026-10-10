// =============================================================================
// night_sky.gdshader  -  A starry night sky with a moon, for the title intro
// -----------------------------------------------------------------------------
// WHAT:  A dark blue gradient (lighter at the horizon), a field of small stars
//        from a hashed grid, and a soft moon disc with a halo.
// WHY:   The intro tilts the camera up to a sky that fills 60% of the screen;
//        the ProceduralSky of the night preset is a flat dark blue with no
//        stars. Nothing here uses TIME, so the sky's radiance map is built
//        once and costs nothing per frame.
// USAGE: HdView.set_sky_material(ShaderMaterial with this shader). Stars stay
//        under 1.0 so the scene's bloom threshold does not halo them.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with <3 from your friendly hacker - er2oneousbit
// =============================================================================
shader_type sky;

uniform vec3 zenith : source_color = vec3(0.006, 0.012, 0.05);
uniform vec3 horizon : source_color = vec3(0.05, 0.08, 0.17);
uniform vec3 below : source_color = vec3(0.01, 0.015, 0.03);
// Where the moon sits (a direction; the camera looks down -Z).
uniform vec3 moon_dir = vec3(0.5, 0.45, -0.75);
uniform float moon_size : hint_range(0.005, 0.12) = 0.032;
uniform float star_density : hint_range(0.0, 0.2) = 0.07;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.42));
	col = mix(col, below, clamp(-d.y * 5.0, 0.0, 1.0));

	if (!AT_CUBEMAP_PASS && d.y > -0.02) {
		// Stars: one candidate per grid cell (azimuth, elevation).
		vec2 uv = vec2(atan(d.x, -d.z), asin(clamp(d.y, -1.0, 1.0))) * 85.0;
		vec2 cell = floor(uv);
		vec2 f = fract(uv) - 0.5;
		float r = hash21(cell);
		if (r > 1.0 - star_density) {
			vec2 jitter = vec2(hash21(cell + 7.1), hash21(cell + 13.7)) - 0.5;
			float dist = length(f - jitter * 0.6);
			float size = mix(0.07, 0.17, hash21(cell + 3.3));
			float bright = mix(0.35, 0.95, hash21(cell + 9.9));
			col += vec3(0.85, 0.9, 1.0) * bright * smoothstep(size, 0.0, dist);
		}
	}

	// Moon: a bright disc, a soft halo.
	vec3 m = normalize(moon_dir);
	float ang = acos(clamp(dot(d, m), -1.0, 1.0));
	float disc = smoothstep(moon_size, moon_size * 0.92, ang);
	float halo = exp(-pow(ang / (moon_size * 4.5), 2.0)) * 0.22;
	col += vec3(0.62, 0.7, 0.9) * halo;
	col = mix(col, vec3(0.93, 0.95, 0.88), disc);
	COLOR = col;
}

shader_type canvas_item;
// Post-composite look for a CanvasGroup-hosted cut-out rig: ink contour, pale
// paper halo, hit flash, status tint, ink-burn dissolve. Operates on the
// group's rendered contents so joints and overlapping parts read as one figure.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float outline_px = 2.2;
uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.04, 0.92);
uniform float halo_px = 5.5;
uniform vec4 halo_color : source_color = vec4(0.88, 0.82, 0.70, 0.22);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform vec4 burn_color : source_color = vec4(0.85, 0.35, 0.12, 1.0);
uniform float alpha_mul = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	// un-premultiply what the group buffer holds
	if (c.a > 0.0001) c.rgb /= c.a;
	float figure_a = c.a;
	vec2 o = SCREEN_PIXEL_SIZE * outline_px;
	float na = 0.0;
	na = max(na, textureLod(screen_texture, SCREEN_UV + vec2(o.x, 0.0), 0.0).a);
	na = max(na, textureLod(screen_texture, SCREEN_UV - vec2(o.x, 0.0), 0.0).a);
	na = max(na, textureLod(screen_texture, SCREEN_UV + vec2(0.0, o.y), 0.0).a);
	na = max(na, textureLod(screen_texture, SCREEN_UV - vec2(0.0, o.y), 0.0).a);
	vec2 h = SCREEN_PIXEL_SIZE * halo_px;
	float hn = na;
	hn = max(hn, textureLod(screen_texture, SCREEN_UV + h * 0.7, 0.0).a);
	hn = max(hn, textureLod(screen_texture, SCREEN_UV - h * 0.7, 0.0).a);
	hn = max(hn, textureLod(screen_texture, SCREEN_UV + vec2(h.x, -h.y) * 0.7, 0.0).a);
	hn = max(hn, textureLod(screen_texture, SCREEN_UV + vec2(-h.x, h.y) * 0.7, 0.0).a);
	float oa = clamp(na * 1.4, 0.0, 1.0) * outline_color.a;
	float ha = clamp(hn * 1.2, 0.0, 1.0) * halo_color.a;
	vec3 under = mix(halo_color.rgb, outline_color.rgb, step(0.001, oa));
	float ua = max(oa, ha);
	c.rgb = mix(under, c.rgb, c.a);
	c.a = max(c.a, ua);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * figure_a);
	c *= tint;
	if (dissolve > 0.0) {
		vec2 q = SCREEN_UV / SCREEN_PIXEL_SIZE / 160.0;
		float n = noise(q * 9.0) * 0.7 + noise(q * 28.0) * 0.3;
		float th = dissolve * 1.25;
		c.rgb = mix(burn_color.rgb, c.rgb, smoothstep(th, th + 0.08, n));
		c.a *= smoothstep(th - 0.02, th + 0.02, n);
	}
	c.a *= alpha_mul;
	COLOR = c;
}

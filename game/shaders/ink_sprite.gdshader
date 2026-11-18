shader_type canvas_item;
// Procedural secondary motion for pose sprites cut from the concept sheets.
//  - sway: robe / rag hem flutter that grows toward the bottom of the sprite
//  - stride: lower-body shear that alternates with `phase` (walk / shamble)
//  - breathe: upper-body vertical stretch
//  - flash: hit flash, tint: status tint, dissolve: ink-burn death effect

uniform float time_offset = 0.0;
uniform float sway = 0.0;        // uv units
uniform float stride = 0.0;      // uv units
uniform float phase = 0.0;
uniform float breathe = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform vec4 burn_color : source_color = vec4(0.85, 0.35, 0.12, 1.0);
uniform float alpha_mul = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + time_offset;
	float low = smoothstep(0.45, 0.95, uv.y);
	// cloth flutter: travelling wave along the hem
	uv.x += sway * low * sin(t * 6.0 + uv.y * 14.0 + uv.x * 5.0);
	// stride: alternate lower-body shear, feet move most
	uv.x += stride * low * low * sin(phase);
	// breathing: stretch upper body slightly
	float up = 1.0 - smoothstep(0.1, 0.6, uv.y);
	uv.y += breathe * up * sin(t * 2.2);
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		c.a = 0.0;
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	c *= tint;
	if (dissolve > 0.0) {
		float n = noise(UV * 18.0) * 0.7 + noise(UV * 55.0) * 0.3;
		// burn from the top down a little so it reads as ash drifting
		float th = dissolve * 1.25 - (1.0 - UV.y) * 0.15;
		float edge = smoothstep(th, th + 0.08, n);
		c.rgb = mix(burn_color.rgb, c.rgb, edge);
		c.a *= smoothstep(th - 0.02, th + 0.02, n);
	}
	c.a *= alpha_mul;
	COLOR = c;
}

shader_type canvas_item;
// Screen-space atmosphere: drifting ground fog tinted per zone, aged-paper
// grain and an ink vignette, tying the scene to the concept-sheet look.

uniform vec4 fog_color : source_color = vec4(0.8, 0.7, 0.55, 0.15);
uniform float cam_x = 0.0;
uniform float grain = 0.05;
uniform float vignette = 0.55;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = vec2(uv.x * 3.0 + cam_x * 0.0012 + TIME * 0.03, uv.y * 2.0);
	float f = fbm(p + vec2(TIME * 0.02, 0.0));
	// fog thickest near the ground band, thin in the sky
	float band = smoothstep(0.35, 0.95, uv.y) * 0.8 + 0.2;
	float fog = fog_color.a * band * (0.55 + 0.9 * f);
	vec3 col = fog_color.rgb;
	float a = fog;
	// ink vignette
	vec2 d = uv - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.0, 1.25))) * vignette;
	col = mix(col, vec3(0.06, 0.05, 0.04), v / max(a + v, 0.001));
	a = a + v * (1.0 - a);
	// paper grain
	float g = (hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 12.0)) - 0.5) * grain;
	COLOR = vec4(col + g, clamp(a + abs(g) * 0.5, 0.0, 1.0));
}

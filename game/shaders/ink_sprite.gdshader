shader_type canvas_item;
// Procedural secondary motion for pose sprites cut from the concept sheets.
//  - sway: robe / rag hem flutter that grows toward the bottom of the sprite
//  - stride: lower-body shear that alternates with `phase` (walk / shamble)
//  - breathe: upper-body vertical stretch
//  - flash: hit flash, tint: status tint, dissolve: ink-burn death effect

uniform sampler2D src_tex : filter_linear, repeat_disable;
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
uniform float legs = 0.0;          // thigh swing amplitude (radians)
uniform float leg_lift = 0.0;      // knee bend amplitude (radians)
uniform float hip_w = 0.05;        // lateral hip pivot offset (uv)
uniform float foot_v = 0.95;       // uv y of the feet
uniform float leg_band = 0.13;
uniform float tuck = 0.0;          // airborne: both thighs forward, knees bent (radians)     // half-width of each leg region (uv)
uniform float split_x = 0.5;       // uv x between the legs (feet anchor)
uniform float hip_y = 0.6;         // uv y where the legs start
uniform float outline_px = 3.5;          // texels
uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.04, 0.9);
uniform float halo_px = 9.0;
uniform vec4 halo_color : source_color = vec4(0.88, 0.82, 0.70, 0.22);

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

vec2 rot2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// Inverse-mapped two-bone leg: thigh rotates about the hip pivot, shin bends
// at the knee. side = +1 front leg (toward facing), -1 back leg.
vec4 leg_sample(vec2 uv, vec2 px, float side, float th, float kn) {
	vec2 P = uv * px;
	vec2 hip = vec2((split_x + side * hip_w) * px.x, hip_y * px.y);
	float wy = smoothstep(hip_y - 0.03, hip_y + 0.1, uv.y);
	th *= wy;
	vec2 Q = hip + rot2(P - hip, th);
	vec2 knee = vec2(hip.x, mix(hip_y, foot_v, 0.52) * px.y);
	vec2 S = Q;
	if (Q.y > knee.y) {
		S = knee + rot2(Q - knee, -kn * smoothstep(knee.y, knee.y + 0.04 * px.y, Q.y));
	}
	vec2 su = S / px;
	float hx = split_x + side * hip_w;
	float own = (side > 0.0 ? step(split_x - 0.01, su.x) : step(su.x, split_x + 0.01)) * step(abs(su.x - hx), leg_band);
	if (su.x < 0.0 || su.x > 1.0 || su.y < 0.0 || su.y > 1.0) return vec4(0.0);
	vec4 c = texture(src_tex, su);
	c.a *= own;
	return c;
}

vec4 rig_sample(vec2 uv, vec2 px) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
	if ((legs <= 0.0 && tuck <= 0.0) || uv.y < hip_y - 0.03) {
		return texture(src_tex, uv);
	}
	float sw = sin(phase);
	float cw = cos(phase);
	vec4 f = leg_sample(uv, px, 1.0, legs * sw + tuck * 0.55, leg_lift * max(0.0, cw) + tuck * 1.4);
	vec4 b = leg_sample(uv, px, -1.0, -legs * sw + tuck * 0.15, leg_lift * max(0.0, -cw) + tuck * 1.1);
	vec4 o;
	o.a = f.a + b.a * (1.0 - f.a);
	o.rgb = (f.rgb * f.a + b.rgb * b.a * (1.0 - f.a)) / max(o.a, 0.001);
	// pixels outside both leg bands (hanging sword, robe edges) stay rigid
	float outside = step(leg_band, abs(uv.x - (split_x + hip_w))) * step(leg_band, abs(uv.x - (split_x - hip_w)));
	vec4 r = texture(src_tex, uv) * vec4(1.0, 1.0, 1.0, outside);
	o.rgb = (o.rgb * o.a + r.rgb * r.a * (1.0 - o.a)) / max(o.a + r.a * (1.0 - o.a), 0.001);
	o.a = o.a + r.a * (1.0 - o.a);
	return o;
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
	vec2 px = 1.0 / TEXTURE_PIXEL_SIZE;
	vec4 c = rig_sample(uv, px);
	// thick ink contour: max alpha of 8 neighbours, drawn behind the sprite
	if (outline_px > 0.0) {
		vec2 o = TEXTURE_PIXEL_SIZE * outline_px;
		float na = 0.0;
		na = max(na, rig_sample(uv + vec2(o.x, 0.0), px).a);
		na = max(na, rig_sample(uv - vec2(o.x, 0.0), px).a);
		na = max(na, rig_sample(uv + vec2(0.0, o.y), px).a);
		na = max(na, rig_sample(uv - vec2(0.0, o.y), px).a);
		na = max(na, rig_sample(uv + o * 0.7, px).a);
		na = max(na, rig_sample(uv - o * 0.7, px).a);
		na = max(na, rig_sample(uv + vec2(o.x, -o.y) * 0.7, px).a);
		na = max(na, rig_sample(uv + vec2(-o.x, o.y) * 0.7, px).a);
		float oa = clamp(na * 1.4, 0.0, 1.0) * outline_color.a;
		// pale paper halo just outside the ink line (negative space)
		float ha = 0.0;
		if (halo_px > 0.0) {
			vec2 h = TEXTURE_PIXEL_SIZE * halo_px;
			float hn = 0.0;
			hn = max(hn, rig_sample(uv + vec2(h.x, 0.0), px).a);
			hn = max(hn, rig_sample(uv - vec2(h.x, 0.0), px).a);
			hn = max(hn, rig_sample(uv + vec2(0.0, h.y), px).a);
			hn = max(hn, rig_sample(uv - vec2(0.0, h.y), px).a);
			hn = max(hn, rig_sample(uv + h * 0.7, px).a);
			hn = max(hn, rig_sample(uv - h * 0.7, px).a);
			ha = clamp(hn * 1.2, 0.0, 1.0) * halo_color.a;
		}
		vec3 under = mix(halo_color.rgb, outline_color.rgb, step(0.001, oa) * clamp(oa / max(outline_color.a, 0.001), 0.0, 1.0));
		float ua = max(oa, ha);
		c.rgb = mix(under, c.rgb, c.a);
		c.a = max(c.a, ua);
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

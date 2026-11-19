shader_type canvas_item;
// Volumetric ink-wash character shader for hand-painted animation frames and
// combat pose sprites. Combines baked 2.5D sculpted normal/thickness/cavity
// maps with per-zone directional sunlight/moonlight, light-facing Fresnel rim,
// ground bounce, nearby campfire/seal/taint point lighting, ground-contact AO,
// and zone atmospheric shadow-floor integration so characters sit inside the
// painted scene rather than reading like flat pasted paper cutouts.

uniform sampler2D src_tex : filter_linear, repeat_disable;
uniform sampler2D normal_tex : filter_linear, repeat_disable;
uniform float use_normal = 0.0;
uniform float facing_sign = 1.0;
uniform float air_height = 0.0;
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
uniform float tuck = 0.0;
uniform vec4 arm0_sh = vec4(0.0);   // shoulder.xy, hand.xy (uv)
uniform vec4 arm0_tp = vec4(0.0);   // tip.xy, arm width, tool width (0 = no bone)
uniform vec3 arm0_x = vec3(0.0);    // rotation (rad), offset.xy (uv)
uniform vec4 arm1_sh = vec4(0.0);
uniform vec4 arm1_tp = vec4(0.0);
uniform vec3 arm1_x = vec3(0.0);
uniform float torso_twist = 0.0;  // upper-body counter-rotation about the hips (radians)
uniform float ribbon = 0.0;       // head ribbon / hair flutter (uv units)          // airborne: both thighs forward, knees bent (radians)     // half-width of each leg region (uv)
uniform float split_x = 0.5;       // uv x between the legs (feet anchor)
uniform float hip_y = 0.6;         // uv y where the legs start
uniform float outline_px = 0.0;
uniform vec4 outline_color : source_color = vec4(0.14, 0.11, 0.09, 0.30);
uniform float halo_px = 0.0;
uniform vec4 halo_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Per-zone 2.5D environmental lighting & atmospheric perspective
uniform vec3 key_dir = vec3(0.62, -0.64, 0.45);
uniform vec3 key_color : source_color = vec3(1.10, 1.02, 0.89);
uniform vec3 shadow_color : source_color = vec3(0.68, 0.64, 0.60);
uniform vec3 rim_color : source_color = vec3(1.16, 1.02, 0.80);
uniform float rim_strength = 0.28;
uniform vec3 bounce_color : source_color = vec3(0.86, 0.72, 0.54);
uniform float bounce_strength = 0.16;
uniform vec4 haze_color : source_color = vec4(0.76, 0.66, 0.54, 0.13);
uniform vec3 soil_color : source_color = vec3(0.52, 0.42, 0.32);
uniform float ground_ao = 0.24;

// Nearby dynamic light (campfires, arena talisman barriers, taint pools)
uniform vec3 point_dir = vec3(0.0, 0.0, 1.0);
uniform vec3 point_color : source_color = vec3(1.0, 0.58, 0.22);
uniform float point_strength = 0.0;

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

vec4 leg_rig(vec2 uv, vec2 px) {
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

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float k = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - a - ab * k);
}

// 1 inside the bone's capsules (arm segment + optional tool segment), px space
float in_bone(vec2 p, vec4 sh, vec4 tp, vec2 px) {
	if (tp.z <= 0.0) return 0.0;
	vec2 s = sh.xy * px;
	vec2 h = sh.zw * px;
	float r = tp.z * px.x;
	float inside = step(seg_dist(p, s, h), r);
	if (tp.w > 0.0) {
		inside = max(inside, step(seg_dist(p, h, tp.xy * px), tp.w * px.x));
	}
	return inside;
}

vec4 bone_layer(vec2 uv, vec2 px, vec4 sh, vec4 tp, vec3 x) {
	if (tp.z <= 0.0) return vec4(0.0);
	vec2 P = uv * px;
	vec2 s = sh.xy * px;
	vec2 Q = s + rot2(P - s - x.yz * px, -x.x);
	if (in_bone(Q, sh, tp, px) < 0.5) return vec4(0.0);
	vec2 qu = Q / px;
	if (qu.x < 0.0 || qu.x > 1.0 || qu.y < 0.0 || qu.y > 1.0) return vec4(0.0);
	return texture(src_tex, qu);
}

// where an arm used to be: probe both sides perpendicular to the bone. If both
// sides are body, fill with body texture; if either is background, the limb was
// on the silhouette edge, so leave it empty.
vec4 inpaint(vec2 uv, vec2 px, vec4 sh, vec4 tp) {
	vec2 P = uv * px;
	vec2 a = sh.xy * px;
	vec2 b = sh.zw * px;
	float r = tp.z * px.x;
	if (tp.w > 0.0 && seg_dist(P, b, tp.xy * px) < seg_dist(P, a, b)) {
		a = b;
		b = tp.xy * px;
		r = tp.w * px.x;
	}
	vec2 ax = normalize(b - a + vec2(0.0001));
	vec2 n = vec2(-ax.y, ax.x);
	float d = r * 1.35 + 2.0;
	vec4 A = texture(src_tex, (P + n * d) / px);
	vec4 B = texture(src_tex, (P - n * d) / px);
	if (A.a < 0.5 || B.a < 0.5) return vec4(0.0);
	return mix(A, B, 0.5);
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.001), a);
}

vec4 rig_sample(vec2 uv, vec2 px) {
	vec4 body = leg_rig(uv, px);
	bool any_arm = arm0_tp.z > 0.0 || arm1_tp.z > 0.0;
	if (!any_arm || (abs(arm0_x.x) + abs(arm1_x.x) + length(arm0_x.yz) + length(arm1_x.yz)) < 0.0005) return body;
	vec2 P = uv * px;
	if (in_bone(P, arm1_sh, arm1_tp, px) > 0.5 && abs(arm1_x.x) + length(arm1_x.yz) > 0.0005) body = inpaint(uv, px, arm1_sh, arm1_tp);
	if (in_bone(P, arm0_sh, arm0_tp, px) > 0.5 && abs(arm0_x.x) + length(arm0_x.yz) > 0.0005) body = inpaint(uv, px, arm0_sh, arm0_tp);
	body = over(bone_layer(uv, px, arm1_sh, arm1_tp, arm1_x), body);
	body = over(bone_layer(uv, px, arm0_sh, arm0_tp, arm0_x), body);
	return body;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + time_offset;
	float low = smoothstep(0.45, 0.95, uv.y);
	// cloth flutter: travelling wave along the hem
	uv.x += sway * low * sin(t * 6.0 + uv.y * 14.0 + uv.x * 5.0);
	// stride: alternate lower-body shear, feet move most
	uv.x += stride * low * low * sin(phase);
	// upper body: counter-rotate about the hip line with the stride
	if (torso_twist != 0.0 && UV.y < hip_y + 0.02) {
		vec2 pxs = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 hipp = vec2(split_x, hip_y) * pxs;
		float wgt = smoothstep(hip_y + 0.02, hip_y - 0.08, UV.y);
		uv = (hipp + rot2(uv * pxs - hipp, torso_twist * sin(phase) * wgt)) / pxs;
	}
	// ribbon / hair flutter near the head, trailing behind
	if (ribbon > 0.0) {
		float hw = smoothstep(0.32, 0.05, UV.y);
		uv.x += ribbon * hw * (0.6 + 0.4 * sin(t * 11.0 + UV.y * 30.0));
	}
	// breathing: stretch upper body slightly
	float up = 1.0 - smoothstep(0.1, 0.6, uv.y);
	uv.y += breathe * up * sin(t * 2.2);
	vec2 px = 1.0 / TEXTURE_PIXEL_SIZE;
	vec4 c = rig_sample(uv, px);
	float figure_a = c.a;
	// 2.5D sculptural form lighting, directional rim, ground AO & zone atmosphere
	if (figure_a > 0.01) {
		vec3 N = vec3(0.0, -0.15, 0.98);
		float thick = 0.7;
		float cav_ao = 1.0;
		if (use_normal > 0.5) {
			vec4 nm = texture(normal_tex, clamp(uv, vec2(0.0), vec2(1.0)));
			float nx = (nm.r * 2.0 - 1.0) * facing_sign;
			float ny = nm.g * 2.0 - 1.0;
			float nz = sqrt(max(0.08, 1.0 - clamp(nx * nx + ny * ny, 0.0, 0.92)));
			N = normalize(vec3(nx, ny, nz));
			thick = nm.b;
			cav_ao = nm.a;
		}
		vec3 L = normalize(key_dir);
		float ndotl = dot(N, L) * 0.5 + 0.5;
		float lit_w = smoothstep(0.16, 0.88, ndotl);
		// Sculpted key/shadow colour wrap + painted fold crevice occlusion
		vec3 shade = mix(shadow_color, key_color, lit_w);
		shade *= mix(0.84, 1.04, cav_ao);
		// Upward warm/mire ground bounce on downward-facing planes near the floor
		float near_ground = 1.0 - clamp(air_height / 145.0, 0.0, 1.0);
		float bounce_w = smoothstep(-0.05, 0.85, N.y) * bounce_strength * near_ground;
		shade += bounce_color * bounce_w;
		// Dynamic campfire / talisman seal / taint pool light
		if (point_strength > 0.001) {
			vec3 PL = normalize(point_dir);
			float p_ndotl = max(0.0, dot(N, PL) * 0.62 + 0.38);
			float p_edge = smoothstep(0.74, 0.08, thick);
			shade += point_color * point_strength * (p_ndotl * 0.44 + p_edge * max(0.0, dot(N.xy, PL.xy)) * 0.58);
		}
		c.rgb *= shade;
		// Light-facing directional rim (separates figure in depth with zero sticker border)
		float edge_w = smoothstep(0.60, 0.06, thick) * smoothstep(0.05, 0.35, figure_a);
		float rim_facing = smoothstep(-0.10, 0.72, dot(normalize(N.xy + vec2(0.0001)), normalize(L.xy + vec2(0.0001))));
		float luma_c = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb += rim_color * (edge_w * rim_facing * rim_strength * (0.48 + 0.52 * luma_c));
		// Ground contact AO + faint soil dust kiss on boots/hem
		float foot_contact = smoothstep(foot_v - 0.15, foot_v, UV.y) * (1.0 - clamp(air_height / 40.0, 0.0, 1.0));
		c.rgb *= 1.0 - foot_contact * ground_ao;
		c.rgb = mix(c.rgb, soil_color * 0.74, foot_contact * foot_contact * 0.15);
		// Atmospheric perspective: lift deepest ink blacks softly into zone air
		float haze_amt = haze_color.a;
		vec3 dark_floor = haze_color.rgb * 0.34;
		c.rgb = mix(c.rgb, max(c.rgb, dark_floor), haze_amt * 0.85);
		c.rgb = mix(c.rgb, haze_color.rgb, haze_amt * 0.22);
	}
	// Optional legacy contour (disabled by default: outline_px = 0.0)
	if (outline_px > 0.0 && c.a < 0.99) {
		vec2 o = TEXTURE_PIXEL_SIZE * outline_px;
		float na = 0.0;
		na = max(na, rig_sample(uv + vec2(o.x, 0.0), px).a);
		na = max(na, rig_sample(uv - vec2(o.x, 0.0), px).a);
		na = max(na, rig_sample(uv + vec2(0.0, o.y), px).a);
		na = max(na, rig_sample(uv - vec2(0.0, o.y), px).a);
		float oa = clamp(na * 1.4, 0.0, 1.0) * outline_color.a;
		// pale paper halo just outside the ink line (negative space)
		float ha = 0.0;
		if (halo_px > 0.0) {
			vec2 h = TEXTURE_PIXEL_SIZE * halo_px;
			float hn = 0.0;
			hn = max(hn, rig_sample(uv + h * 0.7, px).a);
			hn = max(hn, rig_sample(uv - h * 0.7, px).a);
			hn = max(hn, rig_sample(uv + vec2(h.x, -h.y) * 0.7, px).a);
			hn = max(hn, rig_sample(uv + vec2(-h.x, h.y) * 0.7, px).a);
			hn = max(hn, na);
			ha = clamp(hn * 1.2, 0.0, 1.0) * halo_color.a;
		}
		vec3 under = mix(halo_color.rgb, outline_color.rgb, step(0.001, oa) * clamp(oa / max(outline_color.a, 0.001), 0.0, 1.0));
		float ua = max(oa, ha);
		c.rgb = mix(under, c.rgb, c.a);
		c.a = max(c.a, ua);
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash * figure_a);
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

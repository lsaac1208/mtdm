shader_type canvas_item;
render_mode unshaded;

// UVs are in source texture units. Mirror the section horizontally so both
// endpoints meet. The vertical slice begins just above the exposed rock.
uniform float start_px;
void fragment() {
	vec2 world = UV / TEXTURE_PIXEL_SIZE;
	float u = 1.0 - abs(fract(UV.x * 0.5) * 2.0 - 1.0);
	float depth = clamp(world.y / 225.0, 0.0, 1.0);
	vec2 material_uv = vec2(u, mix(0.851, 0.998, depth));
	vec3 rock = texture(TEXTURE, material_uv).rgb;
	float rim = smoothstep(0.0, 10.0, world.y + (rock.r - 0.5) * 8.0);
	float overlap = smoothstep(start_px, start_px + 300.0, world.x);
	rock *= mix(1.0, 0.51, smoothstep(28.0, 290.0, world.y));
	COLOR = vec4(rock, rim * overlap);
}

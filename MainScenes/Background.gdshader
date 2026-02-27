shader_type canvas_item;

uniform vec2 direction = vec2(0.0, -1.5); // Vertical scrolling
uniform float speed_scale = 0.1;        // Scroll speed
uniform float brightness : hint_range(0.0, 2.0) = 1.0; // Brightness control

void fragment() {
    // Calculate movement offset
    vec2 move = direction * TIME * speed_scale;

    // Sample texture with scrolling
    vec4 col = texture(TEXTURE, fract(UV + move));

    // Apply brightness multiplier
    col.rgb = mix(vec3(0.0), col.rgb, brightness);

    COLOR = col;
}
shader_type canvas_item;

uniform vec2 direction = vec2(0.0, 1.0); // Vertical scrolling
uniform float speed_scale = 0.04;       // Adjust speed as needed

void fragment() {
    // Calculate the movement offset based on time and speed
    vec2 move = direction * TIME * speed_scale;

    // Use the UV coordinates with the movement offset to sample the texture
    COLOR = texture(TEXTURE, fract(UV + move));
}
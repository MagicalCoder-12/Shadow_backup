shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 6.0;
uniform float intensity = 1.5;

void fragment() {
    // Calculate scale factor from 1.0 to 5.0 based on charge
    float pulse = sin(TIME * pulse_speed) * 0.1; // Small pulse variation
    float scale_factor = 1.0 + (charge * 4.0) + (pulse * charge); // 1.0 to 5.0 range
    
    // Center the scaling effect
    vec2 centered_uv = (UV - 0.5) * scale_factor + 0.5;
    
    // Only show texture within the scaled area
    vec4 tex = texture(TEXTURE, centered_uv);
    
    // Cut off edges when scaled
    if (centered_uv.x < 0.0 || centered_uv.x > 1.0 || centered_uv.y < 0.0 || centered_uv.y > 1.0) {
        tex.a = 0.0;
    }

    // Pulsing effect for intensity
    float intensity_pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;

    // Intensity increases as charge increases
    float glow_strength = mix(0.5, intensity, charge);

    tex.rgb *= glow_strength + intensity_pulse * charge;

    // Fade in with charge
    tex.a *= charge;

    COLOR = tex;
}
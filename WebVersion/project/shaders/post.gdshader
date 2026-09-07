shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float hurt : hint_range(0,1) = 0.0;
uniform float brightness : hint_range(.7,1.5) = 1.0;
uniform float grain_strength = .025;
void fragment() {
 vec2 uv = SCREEN_UV;
 vec3 col = texture(screen_texture, uv).rgb;
 float vignette = smoothstep(.88,.22,length((uv-.5)*vec2(1.04,.9)));
 float grain = fract(sin(dot(uv*vec2(1920.,1080.)+fract(TIME)*53.,vec2(12.9898,78.233)))*43758.5453)-.5;
 col *= mix(.56,1.,vignette);
 col += grain*grain_strength;
 col *= brightness;
 col = mix(col,vec3(.25,.015,.007),hurt*(1.-vignette)*.85);
 COLOR = vec4(col,1.0);
}

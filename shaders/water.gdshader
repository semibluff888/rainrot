shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 tint : source_color = vec4(.05,.11,.12,.45);
void fragment() {
 vec2 p = UV * 12.;
 float wave = sin(p.x*7.+TIME*.7)*sin(p.y*6.-TIME*.5)*.03;
 ALBEDO = tint.rgb;
 METALLIC = .55;
 ROUGHNESS = .12;
 NORMAL_MAP = vec3(.5+wave,.5+wave,.99);
 ALPHA = tint.a;
}

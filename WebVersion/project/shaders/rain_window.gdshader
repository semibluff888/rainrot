shader_type spatial;
render_mode unshaded;
uniform vec3 tint : source_color = vec3(.016,.045,.057);
float hash(float x) {return fract(sin(x*78.233)*43758.5453);}
void fragment() {
 vec2 uv=UV;
 float col=floor(uv.x*87.);
 float speed=.35+hash(col)*.8;
 float d=fract(uv.y*2.7+TIME*speed+hash(col)*4.);
 float width=smoothstep(.13,.025,abs(fract(uv.x*87.)-.5));
 float streak=width*smoothstep(.48,.06,d)*step(.51,hash(col));
 float sky=1.-uv.y*.3;
 ALBEDO=tint*sky+vec3(.07,.12,.135)*streak;
 ROUGHNESS=.24;
}

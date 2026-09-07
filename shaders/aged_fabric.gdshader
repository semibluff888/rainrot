shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(.32,.34,.30,1.);
uniform float skin = 0.;
varying vec3 local_pos;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){local_pos=VERTEX;}
void fragment(){
 vec3 p=local_pos;
 float broad=noise3(p*6.)*.6+noise3(p*17.)*.28+noise3(p*49.)*.12;
 float dirt=smoothstep(.40,.22,broad);
 float threads=sin(UV.x*840.)*sin(UV.y*600.)*.014;
 vec3 col=base_color.rgb*(.72+broad*.52+threads*(1.-skin));
 col=mix(col,vec3(.075,.052,.034),dirt*.66);
 float vein=pow(1.-abs(noise3(p*29.)-.5)*2.,18.);
 col=mix(col,vec3(.10,.12,.10),vein*skin*.28);
 ALBEDO=col;
 ROUGHNESS=.93-skin*.1;
 SPECULAR=.13;
}

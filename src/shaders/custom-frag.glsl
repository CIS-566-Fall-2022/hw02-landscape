#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

#define MAX_STEPS 100
#define MAX_DIST 100.f
#define SURF_DIST 0.01

float GetDist(vec3 p) {
    vec4 sphere = vec4(0,0,0,1);    // center.xyz,radius
    float dS = length(p - sphere.xyz) - sphere.w; // dist from sphere = dist from center - radius
    //float dP = p.y; // dist from axis aligned plane
    //float d = min(dS,dP);
    return dS;
}

float RayMarching(vec3 ro, vec3 rd) {
    float dO = 0.f;
    float dS;
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + dO * rd;
        dS = GetDist(p);
        dO += dS;
        if(dS < SURF_DIST || dO > MAX_DIST) {    // max steps reached/max dist reached/ surface has been hit
            break;
        }
    }
    return dO;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_Dimensions.xy)/u_Dimensions.xy;
    
    vec3 ro = u_Eye;
    //// vec3 rd = normalize(vec3(fs_Pos.x, fs_Pos.y, 1.f));  // does not work directly, need to set ray direction in world space not screen space
    // vec3 ref = normalize(u_Ref);
    // vec3 R = normalize(cross(u_Ref, u_Up));
    // float len = length(u_Ref - u_Eye);
    // vec3 V = u_Up * len * u_Dimensions.y/2.f;
    // vec3 H = R * len * u_Dimensions.x/2.f;

    // vec3 p = u_Ref + fs_Pos.x * H + fs_Pos.y * V;
    // vec3 rd = normalize(p - u_Eye);

    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 rd = normalize(p - u_Eye);

    float d = RayMarching(ro, rd);
    out_Col = vec4(d, d, d, 1.0);

    // out_Col = vec4(rd.x,rd.y,rd.z, 1.f);
    // out_Col = vec4(H.x, H.y, H.z, 1.f);

    // out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}

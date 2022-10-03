#version 300 es

precision highp float;

uniform vec2 u_Dimensions;
// uniform float u_Fov;
uniform float u_Time;
uniform vec3 u_Eye;
uniform vec3 u_Ref;
uniform vec3 u_Up;
// uniform mat4 u_ViewInv; 

out vec4 out_Col;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 50.0;
const float EPSILON = 0.0001;

// noise ------------------------------------------
mat2 rotate (float a)
{
    float cosA = cos(a); float sinA = sin(a);
    return mat2(cosA, sinA, -sinA, cosA);
}

float rand (vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float rnd (vec2 p)
{
    return abs(rand(p)) * 0.8 + 0.1;
}

float interpol (float a, float b, float x) {
    // cosine initerpolation
    //float f = (1.0 - cos(x * 3.1415927)) * 0.5;
    //return a*(1.0 - f) + b * f;

    // linear interpolation
    return a*(1.0-x) + b*x;
}

float value (float x, float randX, float c)
{
    float a = min(x / randX, 1.0);
    
    float d = clamp(1.0 - (randX + c), 0.1, 0.9);
    float b = min(1.0, (1.0 - x) / d);
    return a + (b - 1.0);
}

float perlin(vec2 uv)
{

    float t = 8.0; // perlin precision
    float octaves = 8.0;		
    float p = 0.0; // final value							

    for(float i = 0.0; i < octaves; i++)
    {
        float a = rnd(vec2(floor(t * uv.x) / t, floor(t * uv.y) / t));	
        float b = rnd(vec2(ceil(t * uv.x) / t, floor(t * uv.y) / t));	
        float c = rnd(vec2(floor(t * uv.x) / t, ceil(t * uv.y) / t));		
        float d = rnd(vec2(ceil(t * uv.x) / t, ceil(t * uv.y) / t));

        if((ceil(t * uv.x) / t) == 1.0)
        {
            b = rnd(vec2(0.0, floor(t * uv.y) / t));
            d = rnd(vec2(0.0, ceil(t * uv.y) / t));
        }

        float coef1 = fract(t * uv.x);
        float coef2 = fract(t * uv.y);
        p += interpol(interpol(a, b, coef1), interpol(c, d, coef1), coef2) * (1.0 / pow(2.0, (i + 0.6)));
        t *= 2.0;
    }
    return p;
}

float polynoise (vec2 p, float sharpness)
{
    vec2 seed = floor(p);
    vec2 rndv = vec2(rnd(seed.xy), rnd(seed.yx));
    vec2 pt = fract(p);
    float bx = value(pt.x, rndv.x, rndv.y * sharpness);
    float by = value(pt.y, rndv.y, rndv.x * sharpness);
    return min(bx, by) * (0.3 + abs(rand(seed.xy * 0.01)) * 0.7);
}


float polyfbm(vec2 p)
{
    vec2 seed = floor(p);
    mat2 r1 = rotate(.2);
    mat2 r2 = rotate(-1.4);
    mat2 r3 = rotate(1.0);
    
    // 1st octave
    float m1 = polynoise(p * r2, .7);
    
    m1 += polynoise ( r1 * (vec2(0.5, 0.5) + p), clamp(sin(u_Time * 0.05), -0.2, 0.9));
    m1 += polynoise ( r3 * (vec2(0.35, 0.415) + p), clamp(sin(u_Time * 0.1), 0.2, 0.9));
    m1 *= 0.333 * 0.75;
    
    // 2nd octave
    float m2 = polynoise (r3 * (p * 2.0), (sin(u_Time * 0.3)));
    m2 += polynoise (r2 * (p + vec2(0.2, 0.6)) * 2.0, (sin(u_Time * 0.3)));
    m1 += m2 * 0.5 * 0.25;
	
    return m1;
}
// ------------------------------------------------

// SDFs -------------------------------------------
float sphereSDF (vec3 point) {
    return length(point) - 1.0;
}

float planeSDF (vec3 point) {
    return point.y;
}

float roundBoxSDF (vec3 point, vec3 b, float r) {
    vec3 q = abs(point) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sceneSDF (vec3 point) {
    float scene = sphereSDF(point);
    return scene;
}
// ------------------------------------------------

// SDF operations----------------------------------
vec2 unionSDF (vec2 dist1, vec2 dist2) {
    if (dist1.x < dist2.x) {
        return dist1;
    } else {
        return dist2;
    }
}

float intersectionSDF (float dist1, float dist2) {
    return max(dist1, dist2);
}

float subtractSDF (float dist1, float dist2) {
    return max(-dist1, dist2);
}

float heightDisplacement(vec3 p)
{
    vec3 c = (p);
    return (polyfbm(c.xz));
}

float opHeightDisplacement(vec3 p)
{
    float d1 = planeSDF(p);
    float d2 = heightDisplacement(p);
    return d1 + d2;
}
// ------------------------------------------------

vec2 map (vec3 pos) {
    vec2 scene = vec2(opHeightDisplacement(pos), opHeightDisplacement(pos));
    // vec2 scene = vec2(roundBoxSDF(pos - vec3(2.0, 1.0, 3.0), vec3(1.0), 0.1), 1.0);
    // scene = unionSDF(scene, vec2(roundBoxSDF(pos + vec3(2.0, -7.0, 3.0), vec3(1.0), 0.1), 1.0));
    return scene;
}

vec2 raymarch (vec3 eye, vec3 marchDir, float start, float end) {
    float depth = start;
    float height = -1.0;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec2 dist = map(eye + depth * marchDir);
        if (dist.x < EPSILON || depth > end) {
			break;
        }
        depth += dist.x;
        height = dist.y;
    }
    if (depth > end) {
        height = -1.0;
    }
    return vec2(depth, height);
}

vec3 rayDirection (float fov, vec2 size, vec2 uv) {
    vec2 xy = uv - size / 2.0;
    float z = (size.y / 2.0) / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

float softshadow (vec3 eye, vec3 dir, float start, float end) {
    float shadow = 1.0;
    float depth = start;
    int maxSteps = 16;

    for (int i = 0; i < maxSteps; i++) {
        float h = map(eye + dir * depth).x;
        shadow = min(shadow, 8.0 * h / depth);
        depth += clamp(h, 0.02, 0.1);
        if (h < 0.001 || depth > end) {
            break;
        }
    }
    return clamp(shadow, 0.0, 1.0);
}

vec3 estimateNormal (vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

float ambOcc (vec3 pos, vec3 nor) {
    float ao = 0.0;
    float scale = 1.0;

    for (int i = 0; i < 5; i++) {
        float hr = 0.01 + 0.12 * float(i) / 4.0;
        vec3 aoPos =  nor * hr + pos;
        float dd = map(aoPos).x;
        ao += -(dd - hr) * scale;
        scale *= 0.95;
    }
    return clamp( 1.0 - 3.0 * ao, 0.0, 1.0 );
}

vec3 render (vec3 eye, vec3 dir) {
    vec3 color = vec3 (11.0 / 255.0, 0.0, 51.0 / 255.0) + dir.y * cos(u_Time * 0.03)
                * clamp(perlin(vec2(gl_FragCoord.x, gl_FragCoord.y) * 0.01), 0.2, 1.0);
    vec2 result = raymarch(eye, dir, MIN_DIST, MAX_DIST);
    float x = result.x;
    float y = result.y;

    vec3 darkPurple = vec3(55.0 / 255.0, 0.0, 49.0 / 255.0);
    vec3 ruby = vec3(131.0 / 255.0, 34.0 / 255.0, 50.0 / 255.0);
    vec3 copper = vec3(206.0 / 255.0, 137.0 / 255.0, 100.0 / 255.0);

    if (y > -0.5) {
        vec3 pos = eye + x * dir;
        vec3 nor = estimateNormal(pos);
        vec3 ref = reflect(dir, nor);

        // calculate material
        color = 0.45 + 0.35 * sin(vec3(0.05, 0.08, 0.10) * (y - 1.0));
        if (y < 1.0)
        {           
            color = mix(darkPurple, ruby, 0.4);
        }
        if (y < 0.2)
        {           
            color = mix(darkPurple, ruby, 0.8);
        }
        if (y < 0.04)
        {           
            color = mix(copper, ruby, 0.8);
        }
        if (y < 0.008)
        {           
            color = mix(copper, ruby, 0.4);
        }

        //calculate lighting
        float occ = ambOcc( pos, nor );
		vec3  lig = normalize(vec3(-0.4 * sin(u_Time * 0.03), 0.7, -0.6 * cos(u_Time * 0.03)));
		float amb = clamp(0.5 + 0.5 * nor.y, 0.0, 1.0);
        float dif = clamp(dot(nor, lig), 0.0, 1.0);
        float bac = clamp(dot(nor, normalize(vec3(-lig.x, 0.0, -lig.z))), 0.0, 1.0 ) * clamp(1.0-pos.y, 0.0, 1.0);
        float dom = smoothstep(-0.1, 0.1, ref.y);
        float fre = pow(clamp(1.0 + dot(nor, dir), 0.0, 1.0), 2.0);
		float spe = pow(clamp(dot(ref, lig), 0.0, 1.0 ), 16.0);

        //dif *= softshadow( pos, lig, 0.02, 2.5 ) * clamp(cos(u_Time * 0.03), 0.0, 1.0);
        //dom *= softshadow( pos, ref, 0.02, 2.5 ) * clamp(cos(u_Time * 0.03), 0.0, 1.0);

        vec3 lin = vec3(0.0);
        lin += 1.30 * dif * vec3(1.00, 0.80, 0.55);
		lin += 2.00 * spe * vec3(1.00, 0.90, 0.70) * dif;
        lin += 0.40 * amb * vec3(0.40, 0.60, 1.00) * occ;
        lin += 0.50 * dom * vec3(0.40, 0.60, 1.00) * occ;
        lin += 0.50 * bac * vec3(0.25, 0.25, 0.25) * occ;
        lin += 0.25 * fre * vec3(1.00, 1.00, 1.00) * occ;
		color = color * lin;

    	color = mix(color, vec3(1.0, 0.0, 0.0), 1.0 - exp(-0.0002 * x * x * x));
    }

    return vec3(clamp(color, 0.0, 1.0));
}

void main () {
    vec3 forward = normalize(u_Ref - u_Eye);
    vec3 right = normalize(cross(u_Up, forward));
    vec3 dir = rayDirection(100.0, u_Dimensions, vec2(gl_FragCoord.x, gl_FragCoord.y));
    dir = normalize(dir.x * right + dir.y * u_Up + dir.z * forward);

    // out_Col = vec4(dir, 1.0);
    // return;

    //float dist = raymarch(eye, dir, MIN_DIST, MAX_DIST);

    //if (dist > MAX_DIST - EPSILON) {
        // didn't hit anything
    //    out_Col = vec4(0.0, 0.0, 0.0, 0.0);
	//	return;
    //}

    //vec3 p = eye + dist * dir;
    
    //vec3 kA = vec3(0.2, 0.2, 0.2);
    //vec3 kD = vec3(0.7, 0.2, 0.2);
    //vec3 kS = vec3(1.0, 1.0, 1.0);
    //float shiny = 10.0;
    
    //vec3 color = illumination(kA, kD, kS, shiny, p, eye);

    // render scene
    vec3 color = render(u_Eye, dir);

    // gamma
    color = pow(color, vec3(0.4545));

    out_Col = vec4(color, 1.0);
}






#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec4 u_Color;

in vec2 fs_Pos;
out vec4 out_Col;

#define EPSILON          0.01
#define INFINITY         1000000.0
#define MAX_STEPS        128
#define MAX_DEPTH        100.0

#define KEY_LIGHT        vec3(0.9, 0.8, 0.3) * 1.5
#define FILL_LIGHT       vec3(0.2, 0.5, 0.9) * 0.2
#define AMBIENT_LIGHT    vec3(0.9, 0.8, 0.3) * 0.2

#define PI               3.1415926535897932384626433832795

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct Intersection
{
    vec3 normal;
    float t;
};

struct Material
{
    vec3 color;
};

struct DirectionalLight
{
    vec3 direction;
    vec3 color;
};

mat3 rotateY3D(float angle)
{
    return mat3(cos(angle), 0, -sin(angle),
                0, 1, 0, 
                sin(angle), 0, cos(angle));
}

mat3 identity()
{
    return mat3(1, 0, 0,
                0, 1, 0, 
                0, 0, 1);
}

float bias(float b, float t)
{
    return pow(t, log(b) / log(0.5f));
}

// Noise and interpolation functions based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise2Df(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 noise2Dv( vec2 p ) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5,183.3)))) * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float interpolateNoise2D(float x, float y) 
{
    // Get integer and fractional components of current position
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);

    // Get noise value at each of the 4 vertices
    float v1 = noise2Df(vec2(intX, intY));
    float v2 = noise2Df(vec2(intX + 1, intY));
    float v3 = noise2Df(vec2(intX, intY + 1));
    float v4 = noise2Df(vec2(intX + 1, intY + 1));

    // Interpolate in the X, Y directions
    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    return cosineInterpolate(i1, i2, fractY);
}

float fbm2D(vec2 p) 
{
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 4;

    for(int i = 1; i <= octaves; i++)
    {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));

        float perlin = interpolateNoise2D(p.x * freq, p.y * freq);
        total += amp * (0.5 * (perlin + 1.0));
    }
    return total;
}

float worley2D(vec2 p) {
    // Tile space
    p *= 2.0;
    vec2 pInt = floor(p);
    vec2 pFract = fract(p);
    float minDist = 1.0; // Minimum distance

    // Iterate through neighboring cells to find closest point
    for(int z = -1; z <= 1; ++z) {
        for(int x = -1; x <= 1; ++x) {
            vec2 neighbor = vec2(float(x), float(z)); 
            vec2 point = noise2Dv(pInt + neighbor); // Random point in neighboring cell
            
            // Distance between fragment and neighbor point
            vec2 diff = neighbor + point - pFract; 
            float dist = length(diff); 
            minDist = min(minDist, dist);
        }
    }
    // Set pixel brightness to distance between pixel and closest point
    return minDist;
}

// SDF for a sphere centered at objectPos
float sphereSDF(vec3 rayPos, vec3 objectPos, float radius)
{
    return length(rayPos - objectPos) - radius;
}

float roundedBoxSDF(vec3 rayPos, vec3 objectPos, mat3 transform, vec3 b, float r)
{
    vec3 p = (rayPos - objectPos) * transform; //* rotateY3D(-0.528);
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float planeSDF(vec3 rayPos, float h)
{
    return rayPos.y - h; 
}

float groundSDF(vec3 rayPos, out Material mat)
{
    float wOffset = 1.f - worley2D(0.1 * rayPos.xz);
    //float wOffset = 0.0;
    float water = planeSDF(rayPos - wOffset, -43.0);

    float xOffset = fbm2D(0.3 * sin(rayPos.xz + 1.0f));
    float zOffset = cos(0.15 * rayPos.y - 1.0f);
    float cliff = roundedBoxSDF(rayPos, vec3(-85.0 + xOffset, -25.0, -60.0 + zOffset), rotateY3D(-0.408), vec3(20.5, 15.5, 55.5), 5.5);
    float dMin = min(water, cliff);

    //float yOffset = 3.f * cos(0.05 * rayPos.x) * 2.f * sin(0.05 * rayPos.z) + (1.f - xOffset);
    float mNoise = fbm2D(0.01 * rayPos.xz);
    float yOffset = 200.f * mNoise;
    float mountains = roundedBoxSDF(rayPos, vec3(-600.0, -253.0 + yOffset, -200.0 - yOffset), rotateY3D(-0.408), vec3(20.5, 0.5, 500.5), 120.5);

    dMin = min(dMin, mountains);

    if (dMin == water)
    {
        mat.color = mix(vec3(0.1, 0.4, 0.9), vec3(0.1, 0.2, 0.8), wOffset);
    }
    else if (dMin == cliff) {
        mat.color = vec3(0.8, 0.7, 0.6);
    }
    else {
        mat.color = mix(vec3(0.7, 0.3, 0.2), vec3(5.0, 5.0, 5.0), bias(mNoise, 0.03));
    }
    
    return dMin;
}

float treeSDF(vec3 rayPos, out Material mat)
{
    float sphere = sphereSDF(rayPos, vec3(-85.0, -10.0, -60.0), 8.0);
    mat.color = vec3(0.0, 1.0, 0.0);
    return sphere;
}

float bridgeSDF(vec3 rayPos, out Material mat)
{
    // Add sine distortion to origin rayPos to make bridge curve up
    vec3 p = rayPos;
    p.y += sin(0.1f * rayPos.z - 1.5f) + 1.8f; 
    mat3 id = identity();

    // Ground planks
    vec3 q = vec3(p.x, p.y, mod(p.z, 0.4));
    float bridgeFloor = roundedBoxSDF(q, vec3(3.0, 0.0, 0.0), id, vec3(2.0, 0.05, 0.35), 0.1);
    float dMin = bridgeFloor;

    // Vertical planks
    q = vec3(p.x, p.y, mod(p.z, 3.0));
    float bridgeVert1 = roundedBoxSDF(q, vec3(1.1, 1.0, 0.0), id, vec3(0.1, 1.0, 0.2), 0.02);
    dMin = min(dMin, bridgeVert1);

    q = vec3(p.x, p.y, mod(p.z + 0.5, 3.0));
    float bridgeVert2 = roundedBoxSDF(q, vec3(1.1, 0.5, 2.0), id, vec3(0.08, 0.5, 0.08), 0.02);
    dMin = min(dMin, bridgeVert2);

    // Horizontal planks
    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5)) - vec3(0.0, -0.8, 0.0);
    float lower = roundedBoxSDF(q, vec3(1.1, 1.0, 0.0), id, vec3(0.15, 0.09, 3.5), 0.02);
    dMin = min(dMin, lower);

    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5));
    float lower2 = roundedBoxSDF(q, vec3(1.1, 1.1, 0.0), id, vec3(0.08, 0.1, 3.5), 0.02);
    dMin = min(dMin, lower2);
    
    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5)) - vec3(0.0, 0.8, 0.0);
    float lower3 = roundedBoxSDF(q, vec3(1.1, 1.2, 0.0), id, vec3(0.2, 0.05, 3.5), 0.02);
    dMin = min(dMin, lower3);

    // Assign color depending on part of bridge
    if (dMin == bridgeFloor)
    {
        mat.color = vec3(0.5);
    }
    else {
        mat.color = vec3(0.9, 0.1, 0.1);
    }

    return dMin;
}

float sceneSDF(vec3 rayPos, out Material mat)
{
    Material groundMat;
    float ground = groundSDF(rayPos, groundMat);

    Material bridgeMat;
    float bridge = bridgeSDF(rayPos, bridgeMat);
    float dMin = min(ground, bridge);

    Material treeMat;
    //float trees = treeSDF(rayPos, treeMat);
    //dMin = min(dMin, trees);

    // Assign color
    //float dMin = min(ground, bridge);
    if (dMin == ground) {
        mat.color = groundMat.color;
    }
    else if (dMin == bridge) {
        mat.color = bridgeMat.color;
    }
    else {
        mat.color = treeMat.color;
    }
    return dMin;
}

float f(float x, float z)
{
    return 3.f * fbm2D(0.5 * vec2(x, z));
}

vec3 getBackgroundColor(Ray ray)
{
    vec3 color = vec3(0.5, 0.85, 0.85);

    // Ray-plane intersection (from parametric equation of ray - Scratchapixel)
    float t = (2500.f - ray.origin.y) / ray.direction.y;
    if (t > 0.001)
    {
        vec3 p = ray.origin + t * ray.direction;
        float noise = fbm2D(0.0001*p.xz);
        float lambda = smoothstep(0.4, 0.7, noise);
        color = mix(vec3(2.0), color, lambda);
    }

    // Sun
    float sunSize = 5.0;
    vec3 sunPosition = vec3(-1000.0, 73.0, 0.0);
    vec3 sunDirection = normalize(sunPosition - ray.origin);
    vec3 sunColor = vec3(1.0, 0.9, 0.3);
    float angle = acos(dot(ray.direction, sunDirection)) * (360.0 / PI);

    if (angle < sunSize) 
    {
        if (angle < 3.0)
        {
            color = sunColor;
        }
        else 
        {
            color = mix(sunColor, color, (angle - 3.0) / 2.0);
        }
    }

    return color;
}

Ray getRay(vec2 uv)
{
    Ray ray;

    float aspect = u_Dimensions.x / u_Dimensions.y;
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * aspect;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}

vec3 estimateNormal(vec3 p)
{
    Material mat;
    float gx = sceneSDF(vec3(p.x + EPSILON, p.y, p.z), mat) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z), mat);
    float gy = sceneSDF(vec3(p.x, p.y + EPSILON, p.z), mat) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z), mat);
    float gz = sceneSDF(vec3(p.x, p.y, p.z + EPSILON), mat) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON), mat);
    return normalize(vec3(gx, gy, gz));
}

Intersection raymarch(vec2 uv, Ray ray, out Material mat)
{
    Intersection intersection;

    vec3 p = ray.origin;
    for (int i = 0; i < MAX_STEPS; ++i)
    {       
        float dist = sceneSDF(p, mat);
        if (dist < EPSILON)
        {
            intersection.normal = estimateNormal(p);
            intersection.t = length(p - ray.origin);
            return intersection;
        }
        if (intersection.t > MAX_DEPTH)
        {
            break;
        }
        p = p + dist * ray.direction;
    }
    intersection.t = -1.0;
    return intersection;
}

Intersection raymarchTerrain(vec2 uv, Ray ray)
{
    Intersection intersection;

    for (float t = 0.f; t < 5.f; t += 0.01f)
    {     
        vec3 p = ray.origin + t * ray.direction;  
        float height = f(p.x, p.z);
        if (p.y < height)
        {
            intersection.normal = estimateNormal(p);
            //intersection.t = length(p - ray.origin);
            intersection.t = t;
            return intersection;
        }       
    }
    intersection.t = -1.0;
    return intersection;
}

void main() {

    // Material base color (before shading)
    vec3 albedo = vec3(0.5);
    vec3 color = vec3(0.0);

    // Lights
    DirectionalLight lights[3];
    lights[0] = DirectionalLight(normalize(vec3(-10.0, 20.0, -20.0)), KEY_LIGHT);
    lights[1] = DirectionalLight(normalize(vec3(0.0, 1.0, 0.0)), FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(-10.0, 0.0, -20.0)), AMBIENT_LIGHT);

    // Raymarch scene
    vec2 ndc = gl_FragCoord.xy / u_Dimensions.xy;
    ndc = ndc * 2.0 - 1.0;
    Ray ray = getRay(ndc);

    Material mat;
    Intersection isect = raymarch(ndc, ray, mat);
    //Intersection isect = raymarchTerrain(ndc, ray);

    // If intersected scene, shade with color
    // Otherwise, return background color
    if (isect.t > 0.0) 
    {
        for (int i = 0; i < 3; i++)
        {
            float cosTheta = max(0.0, dot(isect.normal, lights[i].direction));
            color += mat.color * lights[i].color * cosTheta;
        }    
    }
    else 
    {
        color = getBackgroundColor(ray);
    }

    // Gamma correction
    color = pow(color, vec3(1.0 / 2.2));
    //color = gain

    // Compute final shaded color
    out_Col = vec4(color.rgb, 1.0);
}

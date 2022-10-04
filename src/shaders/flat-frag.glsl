#version 300 es
precision highp float;

const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;
vec3 sunLight  = normalize( vec3(  0.4, 0.4,  0.48 ) );
vec3 sunColour = vec3(1.0, .9, .83);


uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform sampler2D u_Texture;

in vec2 fs_Pos;
out vec4 out_Col;

#define SUN_KEY_LIGHT vec3(0.6, 1.0, 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.7, 0.2, 0.7) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.6, 1.0, 0.4) * 0.2
#define EPSILON 0.01
#define MAXSTEPS 128
#define NEAR 0.1
#define FAR 100.0
#define TWOPI 6.28319

float time = 0.0;

struct Camera {
    vec3 pos;
    vec3 dir;
};

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct Intersection
{
    vec3 position;
    vec3 normal;
    float distance;
    int material_id;
};

struct DirectionalLight
{
    vec3 dir;
    vec3 color;
};

vec3 rgb(float r, float g, float b)
{
    return vec3(r / 255.0, g / 255.0, b / 255.0);
}

float unionSDF(float d1, float d2){
    return min(d1, d2);
}

float boxSDF(vec3 p, vec3 b)
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float sdCylinder( vec3 p, vec2 h)
{
    vec2 d = abs(vec2(length(p.xz),p.y)) - h;
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float smoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }


float smoothSubtraction( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float smoothIntersection( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

//==================Terrain====================================
float rand (vec2 st) {
    return fract(sin(dot(st.xy,vec2(12.9898,78.233)))*43758.5453123);
}

vec2 grad (vec2 st) {
    float nn = rand(st);
    return vec2(cos(nn * TWOPI), sin(nn * TWOPI));
}

float gradnoise (vec2 st) {
    // returns range -1, 1
    vec2 pa = floor(st);
    vec2 pb = pa + vec2(1.0, 0.0);
    vec2 pc = pa + vec2(0.0, 1.0);
    vec2 pd = pa + vec2(1.0);
    vec2 ga = grad(pa);
    vec2 gb = grad(pb);
    vec2 gc = grad(pc);
    vec2 gd = grad(pd);
    float ca = dot(ga, st - pa);
    float cb = dot(gb, st - pb);
    float cc = dot(gc, st - pc);
    float cd = dot(gd, st - pd);
    vec2 frast = fract(st);
    return mix(
        mix(ca, cb, smoothstep(0.0, 1.0, frast.x)),
        mix(cc, cd, smoothstep(0.0, 1.0, frast.x)),
        smoothstep(0.0, 1.0, frast.y));
}

float perlin (vec2 st, float scale, float freq, float persistence, float octaves) {
    float p = 0.0;
    float amp = 1.0;
    for (float i=0.0; i<octaves; i++) {
        p += gradnoise(st * freq / scale) * amp;
        amp *= persistence;
        freq *= 2.0;
    }
    return p;
}


//================GRASS================
const float GAMMA = 2.2;

const float LIGHT_BRIGHTNESS = 2.0;
const vec3     LIGHT_COLOR = vec3(1, 0.9, 0.7) * LIGHT_BRIGHTNESS;

const float AMBIENT_BRIGHTNESS = 0.5;
const vec3 AMBIENT_COLOR = vec3(0.2, 0.35, 0.6) * AMBIENT_BRIGHTNESS;

float get_mipmap_level(vec2 uv) {
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    return 0.5 * log2(max(dot(dx, dx), dot(dy, dy)));
}

vec4 sample_noise(sampler2D sampler, vec2 uv) {
    ivec2 tex_size = textureSize(sampler, 0);
    float mipmap_level = max(get_mipmap_level(uv * vec2(tex_size)), 0.0);
    int lod = int(floor(mipmap_level));
    float mix_factor = fract(mipmap_level);
    ivec2 texcoords = ivec2(fract(uv) * vec2(tex_size));
    texcoords /= int(pow(2.0, float(lod)));
    texcoords *= int(pow(2.0, float(lod)));
    ivec2 next_texcoords = texcoords;
    next_texcoords /= int(pow(2.0, float(lod + 1)));
    next_texcoords *= int(pow(2.0, float(lod + 1)));
    return mix(texelFetch(sampler, texcoords, 0), texelFetch(sampler, next_texcoords, 0), mix_factor);
}

float get_occlusion_factor(vec3 normal, vec3 sight_dir) {
    return abs(dot(sight_dir, normal));
}

float get_specular_factor(vec2 uv, vec3 normal, vec3 sight_dir) {
    float occlusion_factor = 1.0 - get_occlusion_factor(normal, sight_dir);
    float texture_factor = texture(u_Texture, uv * 0.9 + vec2(0.5)).x;
    return pow(texture_factor, 2.0) * pow(occlusion_factor, 5.0);
}

vec3 get_noisy_normal(vec2 uv, vec3 normal, vec3 sight_dir) {
    float noise_factor = pow(clamp(1.5 - abs(normal.z), 0.0, 1.0), 0.5) * 0.9;
    vec3 noisy_normal = normalize(normal + noise_factor * (sample_noise(u_Texture, uv).xyz - 0.5));
    float mix_factor = pow(get_occlusion_factor(normal, sight_dir), 0.5);
    return mix(normal, noisy_normal, mix_factor);
}

vec3 get_diffuse_color(vec2 uv, vec3 normal, vec3 sight_dir) {
    vec3 base = vec3(0.02, 0.015, 0.005) * 0.5;
    vec3 middle = vec3(0.1, 0.2, 0.0);
    vec3 top = middle;
    
    float occlusion_factor = 1.0 - pow(1.0 - get_occlusion_factor(normal, sight_dir), 2.0);
    
    //float base_factor = (1.0 - sample_noise(iChannel1, uv).x) * 2.0;
    float base_factor = (1.0 - sample_noise(u_Texture, uv).x) * 2.0;
    base_factor = clamp(base_factor - occlusion_factor, 0.0, 1.0);
    base_factor = pow(base_factor, 0.5);
    
    //float top_factor = sample_noise(iChannel1, uv).x * 1.5;
    float top_factor = sample_noise(u_Texture, uv).x * 1.5;
    top_factor = clamp(top_factor - occlusion_factor, 0.0, 1.0);
    top_factor = pow(top_factor, 1.0);
    
    vec3 color = mix(base, middle, base_factor);
    color = mix(color, top, top_factor);
    return color;
}

float light_ambient(vec2 uv, vec3 normal, vec3 sight_dir) {
    //float ao_original = sample_noise(iChannel1, uv).x;
    float ao_original = sample_noise(u_Texture, uv).x;
    float ao_decay = pow(get_occlusion_factor(normal, sight_dir), 2.0);
    return mix(1.0, ao_original, ao_decay);
}

float light_diffuse(vec3 normal, vec3 light_dir, float scattering) {
    float result = clamp(dot(-light_dir, normal) * (1.0 - scattering) + scattering, 0.0, 1.0);
    return result;
}

float light_specular(vec3 normal, vec3 light_dir, vec3 sight_dir, float shininess, float scattering) {
    vec3 reflected = reflect(light_dir, normal);
    float result = max(dot(-sight_dir, reflected), 0.0);
    result *= max(sign(dot(normal, -light_dir)), 0.0);
    result = max(result * (1.0 - scattering) + scattering, 0.0);
    result = pow(result, shininess);
    return result;
}

vec3 render_grass(vec3 normal, vec2 uv, vec3 sight_dir, vec3 light_dir, vec3 light_color, vec3 ambient_color) {
    vec3 noisy_normal = get_noisy_normal(uv, normal, sight_dir);
    vec3 color = get_diffuse_color(uv, normal, sight_dir);
    
    float ambient = light_ambient(uv, noisy_normal, sight_dir) * 1.0;
    
    float diffuse = light_diffuse(noisy_normal, light_dir, 0.1) * 1.0;
    diffuse *= 0.8 + pow(1.0 - get_occlusion_factor(normal, sight_dir), 5.0) * 0.5;

    float specular = light_specular(noisy_normal, light_dir, sight_dir, 2.0, 0.0) * 0.75;
    specular *= get_specular_factor(uv, noisy_normal, sight_dir);
    
    color *= (ambient * ambient_color + diffuse * light_color);
    color += vec3(1.0, 1.0, 0.1) * light_color * specular;
    return color;
}


//===============SDF SHAPE===================================
float sdfSphere(vec3 p, float r) {
    return length(p) - r;
}
float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}
float sdSolidAngle(vec3 pos, vec2 c, float ra)
{
    vec2 p = vec2( length(pos.xz), pos.y );
    float l = length(p) - ra;
    float m = length(p - c*clamp(dot(p,c),0.0,ra) );
    return max(l,m*sign(c.y*p.x-c.x*p.y));
}
float sdTriPrism( vec3 p, vec2 h )
{
    const float k = sqrt(3.0);
    h.x *= 0.5*k;
    p.xy /= h.x;
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0/k;
    if( p.x+k*p.y>0.0 ) p.xy=vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    float d1 = length(p.xy)*sign(-p.y)*h.x;
    float d2 = abs(p.z)-h.y;
    return length(max(vec2(d1,d2),0.0)) + min(max(d1,d2), 0.);
}
float sdBoxFrame( vec3 p, vec3 b, float e )
{
       p = abs(p  )-b;
  vec3 q = abs(p+e)-e;

  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}
float sdEllipsoid( in vec3 p, in vec3 r ) // approximated
{
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
    
}
float sdCone( in vec3 p, in vec2 c, float h )
{
    vec2 q = h*vec2(c.x,-c.y)/c.y;
    vec2 w = vec2( length(p.xz), p.y );
    
    vec2 a = w - q*clamp( dot(w,q)/dot(q,q), 0.0, 1.0 );
    vec2 b = w - q*vec2( clamp( w.x/q.x, 0.0, 1.0 ), 1.0 );
    float k = sign( q.y );
    float d = min(dot( a, a ),dot(b, b));
    float s = max( k*(w.x*q.y-w.y*q.x),k*(w.y-q.y)  );
    return sqrt(d)* sign(s);
}



float sdfPerlin(vec3 p) {
    return p.y + 4.0 * perlin(p.xz, 6.0, 0.5, 0.5, 5.0) + 0.5;
}

//==================Mushroom===================================
float mushroom(vec3 queryPos){
    float sphere = sphereSDF(queryPos, vec3(0.0, 1.4, -5.0), 1.0);
    float box = boxSDF(queryPos, vec3(0.0, 1.4, -4.0));
    float upPart = smoothSubtraction(box, sphere, 0.2);
    float capsuleRoot = capsuleSDF(queryPos, vec3(0.0, 0.5, 0.0), vec3(0.0, 1.5, 0.0), 0.3);
        
    float mushroom = smoothUnion(upPart, capsuleRoot, 0.2);
    return mushroom;
}

//float sceneSDF(vec3 queryPos)
//{
//
//    //float plane = planeSDF(queryPos, -1.0);
//
//    //float moon1 = sdfSphere(p + vec3(-60.0, -40.0, -70.0), 5.0);
//    //float moon2 = sdfSphere(p + vec3(-30.0, -20.0, -70.0), 2.0);
//    float land = sdfPerlin(vec3(queryPos.x, queryPos.y, queryPos.z));
////
////    float mushrooms = 0.0;
////
////    vec3 offset = vec3(2.0, 0.0, 0.0);
//    //float mushroom1 = mushroom(queryPos);
//    //mushrooms = mushroom1;
//    //float sphere = sphereSDF(queryPos, vec3(0.0, 1.4, -5.0), 1.0);
//
//   // return plane;
//    return land;
//    //return min(min(moon1, moon2), land);
//
//}

float sceneSDF(vec3 queryPos)
{
    float land = sdfPerlin(vec3(queryPos.x, queryPos.y, queryPos.z));
    float box = sdCylinder(queryPos, vec2(0.2, 6));
    float solid = sdSolidAngle(queryPos + vec3(0, -5.4, 0) , vec2(1.2, 1.2), 0.9);
    float towerone = smoothUnion(solid, box, 0.2);
    
    vec3 offset = vec3(0.4, 0.75, 0.0);
    box = sdCylinder(queryPos + offset, vec2(0.1, 6));
    solid = sdSolidAngle(queryPos + offset + vec3(0, -5.4, 0) , vec2(0.5, 0.5), 0.76);
    float towertwo = smoothUnion(solid, box, 0.2);
    
    offset = vec3(0.5, 1.5, 0.0);
    box = sdCylinder(queryPos + offset, vec2(0.1, 6));
    solid = sdSolidAngle(queryPos + offset + vec3(0, -5.4, 0) , vec2(0.5, 0.5), 0.7);
    float towerthree = smoothUnion(solid, box, 0.2);
    
    offset = vec3(-0.4, 0.75, 0.0);
    box = sdCylinder(queryPos + offset, vec2(0.1, 6));
    solid = sdSolidAngle(queryPos + offset + vec3(0, -5.4, 0) , vec2(0.5, 0.5), 0.76);
    float towerfour = smoothUnion(solid, box, 0.2);
    
    offset = vec3(-0.5, 1.5, 0.0);
    box = sdCylinder(queryPos + offset, vec2(0.1, 6));
    solid = sdSolidAngle(queryPos + offset + vec3(0, -5.4, 0) , vec2(0.5, 0.5), 0.7);
    float towerfive = smoothUnion(solid, box, 0.2);
    
    float towers = smoothUnion(towertwo, towerone, 0.2);
    towers = smoothUnion(towers, towerthree, 0.2);
    towers = smoothUnion(towers, towerfour, 0.2);
    towers = smoothUnion(towers, towerfive, 0.2);
    
    //temple
    offset = vec3(-4.5, 1.0, 0.0);
    float boxone = sdBox(queryPos, vec3(8.0, 1.0, 3.0));
    float boxtwo = sdBox(queryPos + offset, vec3(1.0, 2.3, 1.0));
    float boxthree = sdBox(queryPos + offset, vec3(1.8, 2.1, 1.8));
    float boxfour = sdBox(queryPos + offset, vec3(1.5, 2.2, 1.5));
    
    float cy2 = sdCylinder(queryPos + offset + vec3(-0.9, 0.0, 0.0), vec2(0.05, 3.0));
    float cy3 = sdCylinder(queryPos + offset + vec3(-0.9, 0.0, 0.5), vec2(0.05, 3.0));
    float cy4 = sdCylinder(queryPos + offset + vec3(-0.9, 0.0, 1.0), vec2(0.05, 3.0));
    float cy5 = sdCylinder(queryPos + offset + vec3(-0.9, 0.0, -0.5), vec2(0.05, 3.0));
    float cy6 = sdCylinder(queryPos + offset + vec3(-0.9, 0.0, -1.0), vec2(0.05, 3.0));
    
    float cy7 = sdCylinder(queryPos + offset + vec3(0.9, 0.0, 0.0), vec2(0.05, 3.0));
    float cy8 = sdCylinder(queryPos + offset + vec3(0.9, 0.0, 0.5), vec2(0.05, 3.0));
    float cy9 = sdCylinder(queryPos + offset + vec3(0.9, 0.0, 1.0), vec2(0.05, 3.0));
    float cy10 = sdCylinder(queryPos + offset + vec3(0.9, 0.0, -0.5), vec2(0.05, 3.0));
    float cy11 = sdCylinder(queryPos + offset + vec3(0.9, 0.0, -1.0), vec2(0.05, 3.0));
    
    float cy12 = sdCylinder(queryPos + offset + vec3(-0.5, 0.0, -1.0), vec2(0.05, 3.0));
    float cy13 = sdCylinder(queryPos + offset + vec3(0.0, 0.0, -1.0), vec2(0.05, 3.0));
    float cy14 = sdCylinder(queryPos + offset + vec3(0.5, 0.0, -1.0), vec2(0.05, 3.0));
    
    float cy15 = sdCylinder(queryPos + offset + vec3(-0.5, 0.0, 1.0), vec2(0.05, 3.0));
    float cy16 = sdCylinder(queryPos + offset + vec3(0.0, 0.0, 1.0), vec2(0.05, 3.0));
    float cy17 = sdCylinder(queryPos + offset + vec3(0.5, 0.0, 1.0), vec2(0.05, 3.0));
    
    float boxes = smoothUnion(boxone, boxtwo, 0.2);
    boxes = smoothUnion(boxes, boxthree, 0.2);
    boxes = smoothUnion(boxes, boxfour, 0.2);
    
    float cy = smoothUnion(cy2, cy3, 0.2);
    cy = smoothUnion(cy, cy4, 0.2);
    cy = smoothUnion(cy, cy5, 0.2);
    cy = smoothUnion(cy, cy6, 0.2);
    cy = smoothUnion(cy, cy7, 0.2);
    cy = smoothUnion(cy, cy8, 0.2);
    cy = smoothUnion(cy, cy9, 0.2);
    cy = smoothUnion(cy, cy10, 0.2);
    cy = smoothUnion(cy, cy11, 0.2);
    cy = smoothUnion(cy, cy12, 0.2);
    cy = smoothUnion(cy, cy13, 0.2);
    cy = smoothUnion(cy, cy14, 0.2);
    cy = smoothUnion(cy, cy15, 0.2);
    cy = smoothUnion(cy, cy16, 0.2);
    cy = smoothUnion(cy, cy17, 0.2);
    
    
    float roof = sdBox(queryPos + offset + vec3(0.0, -3.0, 0.0), vec3(1.0, 0.06, 1.0));
    float roofcube = sdBox(queryPos + offset + vec3(0.0, -3.2, 0.0), vec3(0.8, 0.03, 0.8));

    roof = smoothUnion(roof, roofcube, 0.2);
    
    
    land = smoothUnion(land, boxes, 0.2);
    land = smoothUnion(land, cy, 0.2);
    land = smoothUnion(land, roof, 0.2);
    land = smoothUnion(land, towers, 0.2);
    return land;
    
}


Ray getRay(vec2 uv) {
    Ray ray;

    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}

vec3  estimateNormal(vec3 p) {
    vec3 v1 = vec3(1.0, -1.0, -1.0);
    vec3 v2 = vec3(-1.0, -1.0, 1.0);
    vec3 v3 = vec3(-1.0, 1.0, -1.0);
    vec3 v4 = vec3(1.0, 1.0, 1.0);
    return normalize(
        v1 * sceneSDF(p + v1*EPSILON) +
        v2 * sceneSDF(p + v2*EPSILON) +
        v3 * sceneSDF(p + v3*EPSILON) +
        v4 * sceneSDF(p + v4*EPSILON)
    );
}


Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;

    vec3 queryPoint = ray.origin;
    float dep = NEAR;
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        float distanceToSurface = sceneSDF(queryPoint);
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = estimateNormal(queryPoint);
            intersection.distance = length(queryPoint - ray.origin);
            return intersection;
        }
        dep += distanceToSurface;
        queryPoint = queryPoint + ray.direction * distanceToSurface;
        if(dep >= FAR) {
            intersection.position = queryPoint + vec3(dep);
            intersection.normal = estimateNormal(queryPoint);
            return intersection;
        }
    }

    intersection.distance = -1.0;
    return intersection;
}



vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    float texture_factor = texture(u_Texture, uv).x;

    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    

    backgroundColor = SUN_KEY_LIGHT;

    
    vec3 n = estimateNormal(intersection.position);


    //vec3 color = render_grass(n, uv, u_Ref, lights[0].dir, lights[0].color, AMBIENT_COLOR);
    vec3 color = vec3(0.0);
    if (intersection.distance > 0.0)
    {
        for(int i = 0; i < 3; ++i) {
            vec3 amb = mix(AMBIENT_COLOR, vec3(texture_factor), 0.1);
            color += render_grass(n, uv, u_Ref, lights[i].dir, lights[i].color, amb);
        }
    }
    else
    {
        color = vec3(0.5, 0.7, 0.9);
    }
        color = pow(color, vec3(1. / 2.2));
        return color;
}


float distToSurface(Camera c, out vec3 ip) {
    float depth = NEAR;
    for (int i=0; i<MAXSTEPS; i++) {
        ip = c.pos + c.dir * depth;
        float distToScene = sceneSDF(ip);
        if (distToScene < EPSILON) {
            return depth;
        }
        depth += distToScene;
        if (depth >= FAR) {
            return FAR;
        }
    }
    return depth;
}

float lambert(vec3 norm, vec3 lpos) {
    return max(dot(norm, normalize(lpos)), 0.0);
}

void main() {

    vec3 col = getSceneColor(fs_Pos.xy);
    vec4 diffuseCol = vec4(col, 1.0);
//
//    vec4 text = texture(u_Texture, vec2(u, v));
//    diffuseCol = mix(diffuseCol, text, 0.2);
    out_Col = vec4(diffuseCol.rgb, diffuseCol.a);
    
}

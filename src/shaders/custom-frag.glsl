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

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define SUN_KEY_LIGHT vec3(0.6, 1.0, 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.7, 0.2, 0.7) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.6, 1.0, 0.4) * 0.2
const float EPSILON = 1e-2;

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

struct Geom {
    float t;
    int material_id;    
};

/*
 ******************************************************
 * Noise Functions
 ******************************************************
 */

float hash( float n )
{
    return fract(sin(n)*43758.5453);
}

float random2D( vec2 x )
{
    vec2 p = floor(x);
    vec2 f = fract(x);

    f = f*f*(3.0-2.0*f);

    float n = p.x*57.0 + p.y * 50.0;

    return mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
               mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
}


float interpNoise2D(vec2 p) {
    int intX = int(floor(p.x));
    float fractX = fract(p.x);
    int intY = int(floor(p.y));
    float fractY = fract(p.y);

    float v1 = random2D(vec2(intX, intY));
    float v2 = random2D(vec2(intX + 1, intY));
    float v3 = random2D(vec2(intX, intY + 1));
    float v4 = random2D(vec2(intX + 1, intY + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}

float fbm2D(vec2 p, float freq, float persistence, float amp) {
    float total = 0.f;
    //float persistence = 0.5f;
    int octaves = 8;
    //float freq = 2.f;
    //float amp = 2.f;//0.5f;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise2D(p.xy * freq) * amp;
        freq *= 2.f;
        amp *= persistence;
    }
    return total;
	// float v = 0.0;
    // int octaves = 8;
	// vec2 shift = vec2(100);
	// // Rotate to reduce axial bias
    // mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
	// for (int i = 0; i < octaves; ++i) {
	// 	v += amp * interpNoise2D(p);
	// 	p = rot * p * 2.0 + shift;
	// 	amp *= persistence;
	// }
	// return v;
}


/*
 ******************************************************
 * Signed Distance Functions
 ******************************************************
 */
float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float boxSDF( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float roundBoxSDF( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float torusSDF( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float roundedCylinderSDF( vec3 queryPos, float ra, float rb, float h )
{
  vec2 d = vec2( length(queryPos.xz)-2.0 * ra+rb, abs(queryPos.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float cappedCylinderSDF( vec3 queryPos, float h, float r )
{
  vec2 d = abs(vec2(length(queryPos.xz), queryPos.y)) - vec2(h,r);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
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

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); }

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h); }

vec3 rotateY(vec3 p, float amt) {
    return vec3(cos(amt) * p.x + sin(amt) * p.z, p.y, -sin(amt) * p.x + cos(amt) * p.z);
}

vec3 rotateX(vec3 p, float amt) {
    return vec3(p.x, cos(amt) * p.y - sin(amt) * p.z, sin(p.y) + cos(p.z));
}

vec3 rotateZ(vec3 p, float amt) {
    return vec3(cos(amt) * p.x - sin(amt) * p.y, cos(amt) * p.x + sin(amt) * p.y, p.z);
}

float mountainHeightFunc(vec3 p) {
    //vec2 randomOffset = vec2(hash(p.x/12.f), hash(p.z/12.f)) * 0.2f;
    // vec2 randomOffset = vec2(0.3f, 0.3f);
    float fbmMountains = 0.f; //fbm2D((p.xz) / 12.f, 0.5, 0.2, 18.f); //fbm2D((p.xz) * 0.007f, 0.6, 0.2, 400.f);
    float terrainNoise = 1.f * fbm2D(p.xz, 0.8, 0.5, 0.2f);
    float yOffset = -0.7f;//-2.f;
    return  fbmMountains + terrainNoise + yOffset;
}  

mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float sceneSDF(vec3 p) {

    // move down
    p += vec3(0.0, 3.0, 0.0);

    // coffee mug
    float dMugOuter = roundedCylinderSDF( p, 0.6f, 0.2f, 1.f);
    float dMugInner = roundedCylinderSDF( p - vec3(0.f, 0.4f, 0.f), 0.5f, 0.2f, 1.f);
    // vec3 rotatedP = rotateZ(p, 60.f * 3.14f/ 180.f);
    vec3 pRotMugHandle = p + vec3(-1.5f, 0.0, 0.0);
    pRotMugHandle.yz *= rot(90.f * 3.14f/ 180.f);
    float dMugHandle = torusSDF(pRotMugHandle, vec2(0.7f, 0.07));

    float dMugTemp = min(dMugOuter, dMugHandle);//smoothUnion(dMugOuter, dMugHandle, 0.2f);
    float dMug = max(dMugTemp, -dMugInner);
    
    float dCoffee = cappedCylinderSDF(p - vec3(0.f, 0.4f, 0.f), 1.f, 0.01f);
    float dCoffeeMug = min(dCoffee, dMug);

    Geom gCoffeeMug;
    gCoffeeMug.t = dCoffeeMug;
    gCoffeeMug.material_id = 0;

    // pen
    vec3 pRotPen = vec3(p + vec3(2.5f, 0.3, 0.0));
    float a = 90.f * 3.14f/ 180.f;

    pRotPen.xz = rot(45.f * 3.14f/ 180.f) * pRotPen.xz;    // rotation about Y-axis
    pRotPen.yz = rot(90.f * 3.14f/ 180.f) * pRotPen.yz;   // rotation about X-axis
    float dPenBase = roundedCylinderSDF( pRotPen, 0.02f, 0.05f, 1.f);
    float dPenCap = roundedCylinderSDF( pRotPen - vec3(0.0, 0.7f, 0.0), 0.03f, 0.05f, 0.4f);
    float dPenCapHook = boxSDF( pRotPen - vec3(0.07, 0.7f, 0.0), vec3(0.02, 0.4f, 0.02));
    float dPen = min(min(dPenCap, dPenBase), dPenCapHook);

    Geom gPen;
    gPen.t = dPen;
    gPen.material_id = 0;

    // closed book
    vec3 pCBook = p + vec3(2.5f, 0.80, 0.0);

    float dCBookCover = roundBoxSDF(pCBook, vec3(0.8f, 0.25f, 1.1f), 0.2);
    float dCBookPages = boxSDF(pCBook, vec3(0.9f, 0.28f, 1.2f));
    float dCBookPagesCut = boxSDF(pCBook + vec3(-0.2f, 0.f, 0.f), vec3(1.1f, 0.28f, 1.8f));
    float dCBook = min(max(dCBookCover, -dCBookPagesCut), dCBookPages);

    Geom gCBook;
    gCBook.t = dCBook;
    gCBook.material_id = 0;

    // textured plane
    float dP = planeSDF(p + vec3(0.0, 1.75f, 0.0), fbm2D(p.xz, 0.8, 0.5, 0.2f));
    
    float dMountain = 0.f;
    if(p.x > 125.f || p.z > 125.f || p.x < -125.f || p.z < -125.f){
        dMountain = planeSDF(p + vec3(0.0, 1.75f, 0.0), fbm2D((p.xz) / 12.f, 0.5, 0.2, 18.f));
        dP = dMountain;
    }

    Geom gDeskPlane;
    gDeskPlane.t = dP;
    gDeskPlane.material_id = 0;
    
    Geom allGeoms[4] = Geom[4](gCoffeeMug, gPen, gCBook, gDeskPlane);
    float min = MAX_DIST;
    for(int i = 0; i < 4; i++) {
        if(min > allGeoms[i].t) {
            min = allGeoms[i].t;
        }
    }
    return min;
    // float d = min(dCBook, min(dPen, dMug));//min(dCBook, dCBookPages);
    // float d = min(min(dPen, dMug), dCBook);//min(dP, min(dPen, min(dCoffeeMug, dCBook))); //min(dPen, min(dMug, dCBook));
    // return d;

}

/*
 ******************************************************
 * Ray Marching
 ******************************************************
 */

Ray getRay(vec2 uv) {
    Ray ray;

    vec3 ref = normalize(u_Ref);
    vec3 R = normalize(cross(u_Up, u_Ref - u_Eye));
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);  //length(u_Ref - u_Eye);
    vec3 V = len * u_Up;    // * u_Dimensions.y/2.f;
    vec3 H = len * R * u_Dimensions.x/u_Dimensions.y;   // u_Dimensions.x/2.f;

    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}


Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;

    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_STEPS; ++i)
    {
        float distanceToSurface = sceneSDF(queryPoint);
        
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);
            
            return intersection;
        }
        
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.distance = -1.0;
    return intersection;
    
    //     float dO = 0.f;
    //     float dS;
    //     for(int i = 0; i < MAX_STEPS; i++) {
    //         vec3 p = ro + dO * rd;
    //         dS = GetDist(p);
    //         dO += dS;
    //         if(dS < SURF_DIST || dO > MAX_DIST) {    // max steps reached/max dist reached/ surface has been hit
    //             break;
    //         }
    //     }
    //     return dO;
}

/*
 ******************************************************
 * Light Estimation
 ******************************************************
 */
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    backgroundColor = SUN_KEY_LIGHT;
    
    vec3 albedo = vec3(0.5, 0.9, 0.7);

    vec3 n = estimateNormal(intersection.position);
        
    vec3 color = albedo *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir));
    
    if (intersection.distance > 0.0)
    { 
        for(int i = 1; i < 3; ++i) {
            color += albedo *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir));
        }
        // color = 0.5 * (n + vec3(1.));
        // if(isnan(color.r)) {
        //     color = vec3(1., 0., 1.);
        // }
    }
    else
    {
        color = vec3(0.5, 0.7, 0.9);
    }
        // color = pow(color, vec3(1. / 2.2));
        return color;
}

void main() {
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;
    
    // Make symmetric [-1, 1]
    uv = uv * 2.0 - 1.0;

    // Time varying pixel color
    vec3 col = getSceneColor(uv);

    // Output to screen
    out_Col = vec4(col,1.0);
    // out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}

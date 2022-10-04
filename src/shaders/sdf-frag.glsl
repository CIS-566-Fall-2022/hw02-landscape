#version 300 es
// Base code from the LAB02
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
out vec4 out_Col;

const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);

const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);

const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;


// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define SUN_KEY_LIGHT vec3(0.7725, 1.0, 0.9608) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.6863, 0.702, 0.2) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.4118, 0.7216, 0.8667) * 0.2

#define BRICK 0
#define PAVEMENT 1
#define SIDE 2
#define LAMP 3
#define CAR 4
#define HOUSE 5
#define MODBUILD 6
#define TOWER 7

const vec3 materials[8] = vec3[](vec3(0.6824, 0.2588, 0.2588), vec3(0.1137, 0.1137, 0.1137), vec3(0.5882, 0.5882, 0.5882),
                                        vec3(1.0, 0.9529, 0.4471), vec3(0.8392, 0.0, 0.0),
                                         vec3(0.8392, 0.7529, 0.3647),  vec3(0.1216, 0.1216, 0.3098) , vec3(0.5, 0.5, 0.5));


struct Ray 
{
    vec3 origin;
    vec3 direction;
};

struct Intersection 
{
    vec3 position;
    vec3 normal;
    float dist;
    int material_id;
};

struct DirectionalLight
{
    vec3 dir;
    vec3 color;
};

struct Geo 
{
    float dist;
    int material_id;
};

// Noise functions taken from previous hw

float noise3D( vec3 p )
{
    return fract(sin((dot(p, vec3(127.1,
                                  311.7,
                                  191.999)))) *         
                 43758.5453);
}

float cosine_interpolate(float a, float b, float t)
{
    // Result in range [0, 1]
    float cos_t = (1.0 - cos(t * 3.141592653589)) * 0.5;
    return mix(a, b, cos_t);
}

float interpNoise3D(float x, float y, float z)
{
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);
    // Perform trilnear interpolation
    float v1 = noise3D(vec3(intX, intY, intZ));
    float v2 = noise3D(vec3(intX + 1, intY, intZ));
    float v3 = noise3D(vec3(intX, intY + 1, intZ));
    float v4 = noise3D(vec3(intX + 1, intY + 1, intZ));
    // Added z+1 plane
    float v5 = noise3D(vec3(intX, intY, intZ + 1));
    float v6 = noise3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3D(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3D(vec3(intX + 1, intY + 1, intZ + 1));
    // Interpolate points
    // in X axis:
    float i1 = cosine_interpolate(v1, v2, fractX);
    float i2 = cosine_interpolate(v3, v4, fractX);
    float i3 = cosine_interpolate(v5, v6, fractX);
    float i4 = cosine_interpolate(v7, v8, fractX);
    // in Y axis
    float i5 = cosine_interpolate(i1, i2, fractY);
    float i6 = cosine_interpolate(i3, i4, fractY);
    // in Z axis
    float i7 = cosine_interpolate(i5, i6, fractZ);
    return i7;
}


float multiOctaveLatticeValueNoise(float x, float y, float z)
{
    float total = 0.0;
    float persistence = 0.7;
    float freq = 2.0;
    float amp = 0.5;
    // 8 octaves
    for(int i = 1; i <= 8; i++)
    {
        total += interpNoise3D(x * freq,
                               y * freq,
                               z * freq) * amp;

        freq *= 2.0;
        amp *= persistence;
    }
    return total;
}

// Geometry functions

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

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float sdVerticalCapsule( vec3 p, float h, float r )
{
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}

float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
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

float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
  vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}


// Operation functions


float opUnion( float d1, float d2 ) { return min(d1,d2); }

float opSubtraction( float d1, float d2 ) { return max(-d1,d2); }

float opIntersection( float d1, float d2 ) { return max(d1,d2); }

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


vec3 opTranslate( in vec3 p, vec3 translation)
{
    return p - translation;
}

// Special Operations functions

vec3 opRep( vec3 p, in vec3 c)
{
    return mod(p+0.5*c,c)-0.5*c;
}


vec3 opSymX( in vec3 p)
{
    return vec3(abs(p.x), p.y, p.z);
}



// SDF scene functions
 // Buildings
    // Geo baseBuildings;
    // vec3 repeatedBuildingPos = opRep(queryPos, vec3(10, 0, 5));
    // baseBuildings.dist = boxSDF(repeatedBuildingPos, vec3(1.0, 10.0, 1.0));
    // vec3 repeatedWindows = opRep(queryPos, vec3(0.2, 0.2, 0.2));
    // float windowsDist = boxSDF(repeatedWindows, vec3(0.1, 0.2, 0.1));
    // baseBuildings.dist = opSubtraction(windowsDist, baseBuildings.dist);
Geo sceneSDF(vec3 queryPos) 
{
    // Build scene 
    // Buildings
    queryPos = queryPos - vec3(2.5, -2.0, 0);
    // Building 1: classic building
    Geo baseBuildings;
    vec3 repeatedBuildingPos = opRep(queryPos, vec3(5, 0, 10));
    baseBuildings.dist = boxSDF(repeatedBuildingPos, vec3(1.0, 6.0, 1.0));
    vec3 repeatedWindows = opRep(queryPos, vec3(0.5, 0.6, 0.5));
    float windowsDist = boxSDF(repeatedWindows, vec3(0.1, 0.2, 0.1));
    baseBuildings.dist = opSubtraction(windowsDist, baseBuildings.dist);
    float buildingFirstFloor = boxSDF(repeatedBuildingPos, vec3(1.05, 0.5, 1.05));
    baseBuildings.dist = opUnion(baseBuildings.dist, buildingFirstFloor);
    baseBuildings.material_id = BRICK;
    // Building 2: modern building
    Geo modBuildings;
    vec3 repeatedModBuildingPos = opTranslate(queryPos, vec3(0, 0, 4));
    repeatedModBuildingPos = opRep(repeatedModBuildingPos, vec3(5, 0, 10));
    modBuildings.dist = boxSDF(repeatedModBuildingPos, vec3(0.75, 10.0, 0.75));
    vec3 modrepeatedWindows = opRep(queryPos, vec3(0.2, 0.2, 0.2));
    float modwindowsDist = boxSDF(modrepeatedWindows, vec3(0.1, 0.2, 0.1));
    modBuildings.dist = opSubtraction(modwindowsDist, modBuildings.dist);
    modBuildings.material_id = MODBUILD;
    // Building 3: base house
    Geo houses;
    vec3 repeatedHousesPos = opTranslate(queryPos, vec3(0, 0, 6));
    repeatedHousesPos = opRep(repeatedHousesPos, vec3(5, 0, 10));
    houses.dist = boxSDF(repeatedHousesPos, vec3(0.8, 1.25, 1.0));
    vec3 houserepeatedWindows = opRep(queryPos - vec3(0.1), vec3(0.1, 0.61, 0.68));
    float housewindowsDist = boxSDF(houserepeatedWindows, vec3(0.1, 0.1, 0.2));
    houses.dist = opSubtraction(housewindowsDist, houses.dist);
    houses.material_id = HOUSE;
    // Building 4: base house
    Geo midTower;
    vec3 repeatedMidTowerPos = opTranslate(queryPos, vec3(0, 0, 7.9));
    repeatedMidTowerPos = opRep(repeatedMidTowerPos, vec3(5, 0, 10));
    midTower.dist = boxSDF(repeatedMidTowerPos, vec3(0.9, 2, 0.8));
    vec3 midTowerRepeatedWindows = opRep(queryPos - vec3(0.1), vec3(0.5, 0.61, 0.5));
    float midTowerWindowsDist = boxSDF(midTowerRepeatedWindows, vec3(0.2, 0.8, 0.2));
    midTower.dist = opSubtraction(midTowerWindowsDist, midTower.dist);
    float midTowerFirstFloor = boxSDF(repeatedMidTowerPos, vec3(0.9, 0.2, 0.9));
    midTower.dist = opUnion(midTower.dist, midTowerFirstFloor);
    float midTowerLastFloor = boxSDF(repeatedMidTowerPos - vec3(0, 2, 0), vec3(0.9, 0.2, 0.9));
    midTower.dist = opUnion(midTower.dist, midTowerLastFloor);
    midTower.material_id = TOWER;
    // Sidewalk 
    Geo sidewalk;
    vec3 repeatedSideWalkPos = opTranslate(queryPos, vec3(0, 0, 7.2));
    repeatedSideWalkPos = opRep(repeatedSideWalkPos, vec3(5, 0, 10));
    sidewalk.dist = boxSDF(repeatedSideWalkPos, vec3(1.5, 0.07, 4.4));
    sidewalk.material_id = SIDE;
    // Street light part 1
    Geo streetLight;
    vec3 repeatedStreetLightPos = opTranslate(queryPos, vec3(1.3, 0, 1.4));
    repeatedStreetLightPos = opRep(repeatedStreetLightPos, vec3(5, 0, 10));
    streetLight.dist = sdVerticalCapsule(repeatedStreetLightPos, 1.0, 0.02);
    float hStreetLight = capsuleSDF(repeatedStreetLightPos - vec3(0,1,0), vec3(0), vec3(0.7,0,0), 0.02);
    float hpStreetLight = capsuleSDF(repeatedStreetLightPos - vec3(0.6,0.98,0), vec3(0), vec3(0.1,0,0), 0.05);
    streetLight.dist = opUnion(streetLight.dist, hStreetLight);
    streetLight.dist =  opUnion(streetLight.dist, hpStreetLight);
    // Street light part 2
    Geo streetLightTwo;
    vec3 repeatedStreetLightTwoPos = opTranslate(queryPos, vec3(3.7, 0, -2.4));
    repeatedStreetLightTwoPos = opRep(repeatedStreetLightTwoPos, vec3(5, 0, 10));
    streetLightTwo.dist = sdVerticalCapsule(repeatedStreetLightTwoPos, 1.0, 0.02);
    float hStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(0,1,0), vec3(0), vec3(-0.7,0,0), 0.02);
    float hpStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(-0.6,0.98,0), vec3(0), vec3(-0.1,0,0), 0.05);
    streetLightTwo.dist = opUnion(streetLightTwo.dist, hStreetLightTwo);
    streetLightTwo.dist =  opUnion(streetLightTwo.dist, hpStreetLightTwo);
    streetLight.dist = opUnion(streetLight.dist, streetLightTwo.dist);
    // Street light part 3
    repeatedStreetLightTwoPos = opTranslate(queryPos, vec3(3.7, 0, 3));
    repeatedStreetLightTwoPos = opRep(repeatedStreetLightTwoPos, vec3(5, 0, 10));
    streetLightTwo.dist = sdVerticalCapsule(repeatedStreetLightTwoPos, 1.0, 0.02);
    hStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(0,1,0), vec3(0), vec3(-0.7,0,0), 0.02);
    hpStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(-0.6,0.98,0), vec3(0), vec3(-0.1,0,0), 0.05);
    streetLightTwo.dist = opUnion(streetLightTwo.dist, hStreetLightTwo);
    streetLightTwo.dist =  opUnion(streetLightTwo.dist, hpStreetLightTwo);
    streetLight.dist = opUnion(streetLight.dist, streetLightTwo.dist);
    // Street Light part 4
    repeatedStreetLightTwoPos = opTranslate(queryPos, vec3(1.3, 0, 6));
    repeatedStreetLightTwoPos = opRep(repeatedStreetLightTwoPos, vec3(5, 0, 10));
    streetLightTwo.dist = sdVerticalCapsule(repeatedStreetLightTwoPos, 1.0, 0.02);
    hStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(0,1,0), vec3(0), vec3(0.7,0,0), 0.02);
    hpStreetLightTwo = capsuleSDF(repeatedStreetLightTwoPos - vec3(0.6,0.98,0), vec3(0), vec3(0.1,0,0), 0.05);
    streetLightTwo.dist = opUnion(streetLightTwo.dist, hStreetLightTwo);
    streetLightTwo.dist =  opUnion(streetLightTwo.dist, hpStreetLightTwo);
    streetLight.dist = opUnion(streetLight.dist, streetLightTwo.dist);
    streetLight.material_id = LAMP;
    // Car going one way
    Geo car;
    vec3 repeatedCarPos = opTranslate(queryPos + vec3(0, 0, -u_Time * 0.07), vec3(3, 0.1, 10));
    repeatedCarPos = opRep(repeatedCarPos, vec3(5, 0, 4));
    car.dist = sdRoundBox(repeatedCarPos, vec3(0.15, 0.04, 0.35), 0.006);
    float topCar = sdBoxFrame(repeatedCarPos - vec3(0, 0.1, -0.1), vec3(0.13, 0.08, 0.15), 0.03 );
    car.dist = opUnion(car.dist, topCar);
    car.material_id = CAR;
    // wheels
    mat3 rot = mat3(vec3(0,1,0), vec3(-1, 0, 0), vec3(0,0,1));
    vec3 repeatedCarWheelPos = repeatedCarPos - vec3(-0.16, -0.05, 0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    float wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    car.dist = opUnion(car.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(0.16, -0.05, 0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    car.dist = opUnion(car.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(-0.16, -0.05, -0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    car.dist = opUnion(car.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(0.16, -0.05, -0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    car.dist = opUnion(car.dist, wheel);
    // Car going other way
    Geo carOther;
    repeatedCarPos = opTranslate(queryPos, vec3(2.0, 0.1, 10.0 - float(u_Time) * 0.07));
    repeatedCarPos = opRep(repeatedCarPos, vec3(5, 0, 4));
    carOther.dist = sdRoundBox(repeatedCarPos, vec3(0.15, 0.04, 0.35), 0.006);
    topCar = sdBoxFrame(repeatedCarPos - vec3(0, 0.1, 0.1), vec3(0.13, 0.08, 0.15), 0.03 );
    carOther.dist = opUnion(carOther.dist, topCar);
    // wheels
    repeatedCarWheelPos = repeatedCarPos - vec3(-0.16, -0.05, 0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    carOther.dist = opUnion(carOther.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(0.16, -0.05, 0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    carOther.dist = opUnion(carOther.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(-0.16, -0.05, -0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    carOther.dist = opUnion(carOther.dist, wheel);
    repeatedCarWheelPos = repeatedCarPos - vec3(0.16, -0.05, -0.2);
    repeatedCarWheelPos = rot * repeatedCarWheelPos;
    wheel = sdTorus(repeatedCarWheelPos , vec2(0.04, 0.01));
    carOther.dist = opUnion(carOther.dist, wheel);
    car.dist = opUnion(car.dist, carOther.dist);

    // float topCar = sdBoxFrame(repeatedCarPos - vec3(0, 0.1, -0.1), vec3(0.14, 0.08, 0.15), 0.02 );
    // car.dist = opUnion(car.dist, topCar);
    // float topCar = sdBoxFrame(repeatedCarPos - vec3(0, 0.1, -0.1), vec3(0.14, 0.08, 0.15), 0.02 );
    // car.dist = opUnion(car.dist, topCar);
    // float topCar = sdBoxFrame(repeatedCarPos - vec3(0, 0.1, -0.1), vec3(0.14, 0.08, 0.15), 0.02 );
    // car.dist = opUnion(car.dist, topCar);

    // Ground
    Geo plane;
    plane.dist = planeSDF(queryPos, 0.0);
    plane.material_id = PAVEMENT;
    // Add geo to scene array
    Geo scene[8] = Geo[] (baseBuildings, modBuildings, houses, midTower, sidewalk, streetLight, car, plane);
    Geo minSDF = baseBuildings;
    // Calculate minimum sdf
    for (int i = 0; i < 8; i++)
    {
        if (scene[i].dist < minSDF.dist)
        {
            minSDF = scene[i];
        }
    }
    return minSDF;
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

Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;
    
    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        Geo geometry = sceneSDF(queryPoint);
        float distanceToSurface = geometry.dist;
        if (distanceToSurface < EPSILON)
        {
            
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.dist = length(queryPoint - ray.origin);
            intersection.material_id = geometry.material_id;
            return intersection;
        }
        
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.dist = -1.0;
    return intersection;
}


vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).dist - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).dist,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).dist - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).dist,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).dist - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).dist
    ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 13.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 23.0)),
                                 SUN_AMBIENT_LIGHT);
    backgroundColor = vec3(1, 1, 1);
    float noise = multiOctaveLatticeValueNoise(uv.x + sin(u_Time * 0.001) ,  uv.y + sin(u_Time * 0.001), 1.0);
    vec3 sky = vec3(0.2667, 0.2667, 0.2667);
    backgroundColor = mix(sky, backgroundColor, noise);
    vec3 albedo = materials[intersection.material_id];
    vec3 n = estimateNormal(intersection.position);
        
    vec3 color = albedo *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir));
    if (intersection.dist > 0.0)
    { 
        
        for(int i = 1; i < 3; ++i) {
            color += albedo *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir));
        }
        float fogT = smoothstep(20.0, 47.0, intersection.dist);
        
        color = mix(color, backgroundColor, fogT);

    }
    else
    {
        color = backgroundColor;
    }
    // gamma correction
    color = pow(color, vec3(1. / 2.2));
    return color;
}


void main()
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = vec2(gl_FragCoord.x/u_Dimensions.x, gl_FragCoord.y/u_Dimensions.y);
    vec2 uvAux = uv;
    // Make symmetric [-1, 1]
    uv = uv * 2.0 - 1.0;

    // Time varying pixel color
    vec3 col = getSceneColor(uv);
    float greyscaleColor = 0.21 * col.r + 0.72 * col.g + 0.07 * col.b;
    float len = length(uvAux - vec2(0.5, 0.5));
    float maxLength = length(vec2(1,1) - vec2(0.5, 0.5));
    col = vec3(greyscaleColor * ((maxLength - len)/ maxLength));

    // Output to screen
    out_Col = vec4(col,1.0);
}

#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

// ====== Camera
const float FOV = 45.0;

// ====== RAY MARCHING
const int MAX_STEPS = 200;
const float MAX_DIST = 200.0;
const float EPSILON = 0.1;

// ====== material
const int TERRAIN_MATERIAL_ID = 0;
const int TERRAIN_SHADOW_MATERIAL_ID = 7; // to identify the terrain recieves shadows
//const vec3 TERRAIN_COL = vec3(4.0, 44.0, 69.0) / 255.0;
//const vec3 TERRAIN_COL = vec3(30.0, 104.0, 109.0) / 255.0;
const vec3 TERRAIN_COL = vec3(23.0, 71.0, 31.0) / 255.0;
const int TERRAIN2_MATERIAL_ID = 5;
const vec3 TERRAIN2_COL = vec3(8.0, 51.0, 28.0) / 255.0;
const int TERRAIN3_MATERIAL_ID = 6;
const vec3 TERRAIN3_COL = vec3(3.0, 66.0, 4.0) / 255.0;


const int TREE_MATERIAL_ID = 1;
const vec3 TREE_COL = vec3(0.0, 64.0, 3.0) / 255.0;
const int TREE_TRUNK_MATERIAL_ID = 4;
const vec3 TREE_TRUNK_COL = vec3(48.0, 28.0, 14.0) / 255.0;

const int ROAD_MATERIAL_ID = 2;
const vec3 ROAD_COL = vec3(27.0, 36.0, 46.0)/ 255.0;
const int ROAD_MIDDLE_MATERIAL_ID = 3;
const vec3 ROAD_MIDDLE_COL = vec3(94.0, 79.0, 19.0)/ 255.0;

const int CAR_MATERIAL_ID = 8;
const vec3 CAR_COL = vec3(71.0, 10.0, 4.0)/ 255.0;
const int CAR_TIRE_MATERIAL_ID = 9;
const vec3 CAR_TIRE_COL = vec3(19.0, 10.0, 4.0)/ 255.0;
const int CAR_LIGHT_MATERIAL_ID = 10;
const vec3 CAR_LIGHT_COL = vec3(255.0, 247.0, 68.0)/ 255.0;

// day sky color
const vec3 DAY_UPPER_COL = vec3(143.0, 51.0, 118.0) / 255.0;
const vec3 DAY_LOWER_COL = vec3(237.0, 118.0, 12.0) / 255.0;
// night sky color
const vec3 NIGHT_UPPER_COL = vec3(17.0, 55.0, 58.0) / 255.0;
const vec3 NIGHT_LOWER_COL = vec3(202.0, 229.0, 220.0) / 255.0;



// ====== struct Ray & Intersection
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



// ====== HELPER FUNCTIONS

// https://github.com/dmnsgn/glsl-rotate/blob/main/rotation-3d-z.glsl
mat3 rotation3dZ(float angle) {
  float s = sin(angle);
  float c = cos(angle);

  return mat3(
    c, s, 0.0,
    -s, c, 0.0,
    0.0, 0.0, 1.0
  );
}
vec3 rotateZ(vec3 p, float angle) {
  return rotation3dZ(angle) * p;
}

mat3 rotation3dX(float angle) {
  float s = sin(angle);
  float c = cos(angle);

  return mat3(
    1.0, 0.0, 0.0,
    0.0, c, s,
    0.0, -s, c
  );
}

vec3 rotateX(vec3 v, float angle) {
  return rotation3dX(angle) * v;
}

vec3 bendPoint(vec3 p, float k)
{
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    return q;
}

float bias(float t, float b){
  return pow(t, log(b) / log(0.5));
}

float dot2(vec3 p){
  return dot(p, p);
}

// ============== NOISE FUNCTIONS
vec2 random2( vec2 p ) {
    return fract(sin(vec2(dot(p,vec2(127.1, 311.7)),
                          dot(p,vec2(269.5, 183.3))))
                 *43758.5453);
}
float surflet(vec2 p, vec2 gridPoint) {
    // Compute the distance between p and the grid point along each axis, and warp it with a
    // quintic function so we can smooth our cells
    vec2 t2 = abs(p - gridPoint);
    vec2 t = vec2(1.0) - 6.0 * vec2(pow(t2.x, 5.0), pow(t2.y, 5.0)) + 
                         15.0 * vec2(pow(t2.x, 4.0), pow(t2.y, 4.0)) - 
                         10.0 * vec2(pow(t2.x, 3.0), pow(t2.y, 3.0));

    vec2 gradient = random2(gridPoint) * 2.0 - vec2(1.0);
    // Get the vector from the grid point to P
    vec2 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y;
}
float perlinNoise2D(vec2 p) {
	float surfletSum = 0.0;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
				surfletSum += surflet(p, floor(p) + vec2(dx, dy));
		}
	}
	return surfletSum;
}


// --- worley
float noise1D( vec2 p ) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) *
                 43758.5453);
}

float WorleyNoise(vec2 uv)
{
    uv *= 0.8; // Now the space is 10x10 instead of 1x1. Change this to any number you want.
    vec2 uvInt = floor(uv); // grid cell which fragment lies
    vec2 uvFract = fract(uv); // uv lie in the cell
    float minDist = 1.0; // Minimum distance initialized to max.
    for(int y = -1; y <= 1; ++y) {
        for(int x = -1; x <= 1; ++x) {
            vec2 neighbor = vec2(float(x), float(y)); // Direction in which neighbor cell lies
            vec2 point = random2(uvInt + neighbor); // Get the Voronoi centerpoint for the neighboring cell
            //point += (0.5*sin(u_Time * 0.01)+0.5);
            vec2 diff = neighbor + point - uvFract; // Distance between fragment coord and neighbor’s Voronoi point
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    return minDist;
}

// ============== SDFs
float smoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

// https://iquilezles.org/articles/distfunctions/
float cappedCylinderSDF(vec3 p, vec3 a, vec3 b, float r)
{
  vec3  ba = b - a;
  vec3  pa = p - a;
  float baba = dot(ba,ba);
  float paba = dot(pa,ba);
  float x = length(pa*baba-ba*paba) - r*baba;
  float y = abs(paba-baba*0.5)-baba*0.5;
  float x2 = x*x;
  float y2 = y*y*baba;
  float d = (max(x,y)<0.0)?-min(x2,y2):(((x>0.0)?x2:0.0)+((y>0.0)?y2:0.0));
  return sign(d)*sqrt(abs(d))/baba;
}

float coneSDF( vec3 p, vec2 c, float h )
{
    float q = length(p.xz);
    return max(dot(c.xy,vec2(q,p.y)),-h-p.y);
}

float cappedConeSDF(vec3 p, vec3 a, vec3 b, float ra, float rb)
{
  float rba  = rb-ra;
  float baba = dot(b-a,b-a);
  float papa = dot(p-a,p-a);
  float paba = dot(p-a,b-a)/baba;
  float x = sqrt( papa - paba*paba*baba );
  float cax = max(0.0,x-((paba<0.5)?ra:rb));
  float cay = abs(paba-0.5)-0.5;
  float k = rba*rba + baba;
  float f = clamp( (rba*(x-ra)+paba*baba)/k, 0.0, 1.0 );
  float cbx = x-ra - f*rba;
  float cby = paba - f;
  float s = (cbx<0.0 && cay<0.0) ? -1.0 : 1.0;
  return s*sqrt( min(cax*cax + cay*cay*baba,
                     cbx*cbx + cby*cby*baba) );
}

float capsuleSDF( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float roundConeSDF(vec3 p, vec3 a, vec3 b, float r1, float r2)
{
  // sampling independent computations (only depend on shape)
  vec3  ba = b - a;
  float l2 = dot(ba,ba);
  float rr = r1 - r2;
  float a2 = l2 - rr*rr;
  float il2 = 1.0/l2;
    
  // sampling dependant computations
  vec3 pa = p - a;
  float y = dot(pa,ba);
  float z = y - l2;
  vec3 tmp = (pa*l2) - (ba*y);
  float x2 = dot(tmp, tmp);
  float y2 = y*y*l2;
  float z2 = z*z*l2;

  // single square root!
  float k = sign(rr)*rr*rr*x2;
  if( sign(z)*a2*z2>k ) return  sqrt(x2 + z2)        *il2 - r2;
  if( sign(y)*a2*y2<k ) return  sqrt(x2 + y2)        *il2 - r1;
                        return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
}

float roundBoxSDF( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}



float quadSDF( vec3 p, vec3 a, vec3 b, vec3 c, vec3 d )
{
  vec3 ba = b - a; vec3 pa = p - a;
  vec3 cb = c - b; vec3 pb = p - b;
  vec3 dc = d - c; vec3 pc = p - c;
  vec3 ad = a - d; vec3 pd = p - d;
  vec3 nor = cross( ba, ad );

  return sqrt(
    (sign(dot(cross(ba,nor),pa)) +
     sign(dot(cross(cb,nor),pb)) +
     sign(dot(cross(dc,nor),pc)) +
     sign(dot(cross(ad,nor),pd))<3.0)
     ?
     min( min( min(
     dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa),
     dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
     dot2(dc*clamp(dot(dc,pc)/dot2(dc),0.0,1.0)-pc) ),
     dot2(ad*clamp(dot(ad,pd)/dot2(ad),0.0,1.0)-pd) )
     :
     dot(nor,pa)*dot(nor,pa)/dot2(nor) );
}

float roundedCylinderSDF( vec3 p, float ra, float rb, float h )
{
  vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float cutSphereSDF( vec3 p, float r, float h )
{
  // sampling independent computations (only depend on shape)
  float w = sqrt(r*r-h*h);

  // sampling dependant computations
  vec2 q = vec2( length(p.xz), p.y );
  float s = max( (h-r)*q.x*q.x+w*w*(h+r-2.0*q.y), h*q.x-w*q.y );
  return (s<0.0) ? length(q)-r :
         (q.x<w) ? h - q.y     :
                   length(q-vec2(w,h));
}

struct Tree
{
  vec3 position;
  float lowerRadius;
  float upperRadius;
  float halfHeight;
  float tilt; // rotate along z-axis
  vec2 mainCanopy; // x->canopy length y->radius
  vec2 smallTrunk; // x->rotate y->bend 
  vec2 smallTrunkPos; // x->height y->offset
};

float treeSDF(vec3 queryPos, Tree t, out int treeMaterialID)
{
  float noise = perlinNoise2D(queryPos.xy * 0.4);
  vec3 rotateTreePos = rotateZ(queryPos, t.tilt) + vec3(noise*0.2, 0.0, 0.0);
  vec3  pLow = vec3(t.position.x, t.position.y, t.position.z), 
        pHigh = vec3(t.position.x, t.position.y + t.halfHeight, t.position.z); // tree higher point and tree lower point
  float treeTrunk = cappedConeSDF(rotateTreePos, pLow, pHigh, t.lowerRadius, t.upperRadius);

  // float canopy = 0.0;
  vec3 canopyPos = rotateTreePos + vec3(noise * 2.0, noise * 2.0, 0.0);
  float canopy_middle = sphereSDF(canopyPos, vec3(t.position.x, t.position.y + t.halfHeight - 2.0, t.position.z), t.mainCanopy.y);

  // canopy = canopy_middle;
  // float canopy1 = sphereSDF(rotateTreePos, vec3(t.position.x, t.position.y + t.halfHeight - 3.0, t.position.z), t.mainCanopy.y);
  // canopy = smoothUnion(canopy, canopy1, 0.6);
  // float canopy_right1 = sphereSDF(rotateTreePos, vec3(t.position.x + 2.0, t.position.y + t.halfHeight - 3.0, t.position.z), 2.0);
  // canopy = smoothUnion(canopy, canopy_right1, 0.9);
  // float canopy_left1 = sphereSDF(rotateTreePos, vec3(t.position.x-1.2, t.position.y + t.halfHeight - 3.0, t.position.z), 2.0);
  // canopy = smoothUnion(canopy, canopy_left1, 0.2);
  // float canopy_left2 = sphereSDF(rotateTreePos, vec3(t.position.x-1.3, t.position.y + t.halfHeight - 6.0, t.position.z), 1.7);
  // canopy = smoothUnion(canopy, canopy_left2, 0.4);
  // float canopy_right2 = sphereSDF(rotateTreePos, vec3(t.position.x+1.3, t.position.y + t.halfHeight - 6.0, t.position.z), 1.6);
  // canopy = smoothUnion(canopy, canopy_right2, 0.4);

  // vec3 smallTrunkP = rotateZ(queryPos, t.smallTrunk.x); // rotate tree
  // smallTrunkP = bendPoint(smallTrunkP, t.smallTrunk.y);
  // float smallTrunk = roundConeSDF(smallTrunkP, 
  //                                 vec3(t.position.x+1.3, t.position.y + t.smallTrunkPos.y, t.position.z),
  //                                 vec3(t.position.x+1.3, t.position.y + t.smallTrunkPos.x, t.position.z),
  //                                 0.5, 0.1);

  //treeTrunk = smoothUnion(treeTrunk, smallTrunk, 0.4);
  // union trunk and canopy
  float tree = smoothUnion(treeTrunk, canopy_middle, 0.3);
  float treeColor = min(treeTrunk, canopy_middle);
  treeMaterialID = TREE_MATERIAL_ID;
  if(treeColor == treeTrunk){
    treeMaterialID = TREE_TRUNK_MATERIAL_ID;
  }
  return tree;
}

float treeTrunkOnlySDF(vec3 queryPos, Tree t, out int treeMaterialID)
{
  float noise = perlinNoise2D(queryPos.xy * 0.4);
  vec3 rotateTreePos = rotateZ(queryPos, t.tilt) + vec3(noise*0.2, 0.0, 0.0);
  vec3  pLow = vec3(t.position.x, t.position.y, t.position.z), 
        pHigh = vec3(t.position.x, t.position.y + t.halfHeight, t.position.z); // tree higher point and tree lower point
  float treeTrunk = cappedConeSDF(rotateTreePos, pLow, pHigh, t.lowerRadius, t.upperRadius);
  treeMaterialID = TREE_TRUNK_MATERIAL_ID;
  return treeTrunk;
}

float terrainSDF(vec3 queryPos, out int terrianMaterialID)
{
  float mountainArea = -60.0;
  float hillArea = -70.0;
  float noise = perlinNoise2D(queryPos.xz * 0.03);
  vec3 terrianP = queryPos;
  //float heightScaler = mix(5.0, 15.0, queryPos.z);
  if(queryPos.z <= mountainArea){
    terrianP = queryPos + vec3(0.0, noise, 0.0) * 45.0;
  }
  // else if(queryPos.z > mountainArea && queryPos.z < hillArea){
  //   terrianP = queryPos + vec3(0.0, noise, 0.0) * 15.0;
  // }
  else{ 
    terrianP = queryPos + vec3(0.0, noise, 0.0) * 2.0 + vec3(0.0, 10.0, 0.0);
  }
  //terrianP = queryPos + vec3(0.0, noise, 0.0) * 2.0 + vec3(0.0, 10.0, 0.0);
  vec3 pos1 = rotateX(terrianP, -0.3);
  float plane1 = planeSDF(pos1, -20.0 + noise*25.0);
  vec3 pos2 = rotateX(queryPos, -0.1);
  float plane2 = planeSDF(pos2, -8.0 + noise * 4.0);

  terrianMaterialID = TERRAIN_MATERIAL_ID;
  float shadowResult = min(plane1, plane2);
  if(shadowResult == plane2){
    terrianMaterialID = TERRAIN_SHADOW_MATERIAL_ID;
  }
  if(queryPos.z < -140.0){
    terrianMaterialID = TERRAIN2_MATERIAL_ID;
  }
  if(queryPos.z >= -140.0 && queryPos.z < -100.0){
    terrianMaterialID = TERRAIN3_MATERIAL_ID;
  }
  
  float result = smoothUnion(plane1, plane2, 1.0);
  return result;
}

float roadSDF(vec3 queryPos, out int roadMaterrialID){
  vec3 curveRoadPos = vec3(queryPos.x + sin(queryPos.z*0.2 + 0.1), queryPos.y, queryPos.z);
  //float scale = mix(0.4, 0.2, tan(roadPos.z));
  vec3 scaleRoadPos = vec3(curveRoadPos.x * 0.4, curveRoadPos.y, curveRoadPos.z);
  float road = quadSDF(scaleRoadPos, vec3(-0.2, -2.0, -45.0), vec3(-2.5, -5.0, 3.0),
                                vec3(2.5, -5.0, 3.0), vec3(0.2,-2.0, -45.0));
  roadMaterrialID = ROAD_MATERIAL_ID;
  if(scaleRoadPos.x < 0.08 && scaleRoadPos.x > -0.08){
    roadMaterrialID = ROAD_MIDDLE_MATERIAL_ID;
  }
  return road;
}

float forestSDF(vec3 queryPos, out int treeMaterialID){
  float trees = 0.0;
  Tree treeData = Tree(vec3(-10.0, -6.0, -10.0),
                       0.6,0.5, // lower&upper radius
                       15.0, // tree hight
                       0.1, // tilt
                       vec2(5.0, 4.2), // canopy length
                       vec2(0.3, -0.01), // small trunk
                       vec2(15.0, 3.0));
  int tree1MaterialID;
  float tree = treeSDF(queryPos, treeData, tree1MaterialID);
  Tree treeData2 = Tree(vec3(12.0, -8.0, -11.0),
                       0.7,0.5, // lower&upper radius
                       19.0, // tree hight
                       -0.1, // tilt
                       vec2(5.0, 4.0), // canopy length
                       vec2(0.3, 0.01), // small trunk
                       vec2(15.0, 3.0));
  int tree2MaterialID;
  float tree2 = treeSDF(queryPos, treeData2, tree2MaterialID);
  trees = min(tree, tree2);
  int tree3MaterialID;
  Tree treeData3 = Tree(vec3(-10.0, -7.0, -5.0),
                       0.8,0.5, // lower&upper radius
                       16.0, // tree hight
                       0.1, // tilt
                       vec2(5.0, 3.0), // canopy length
                       vec2(0.3, -0.01), // small trunk
                       vec2(15.0, 3.0));
  float tree3 = treeSDF(queryPos, treeData3, tree3MaterialID);
  trees = min(trees, tree3);
  int tree4MaterialID;
  Tree treeData4 = Tree(vec3(14.0, -9.0, -6.0),
                       0.7,0.5, // lower&upper radius
                       19.0, // tree hight
                       -0.1, // tilt
                       vec2(5.0, 4.0), // canopy length
                       vec2(0.3, 0.01), // small trunk
                       vec2(15.0, 3.0));
  float tree4 = treeSDF(queryPos, treeData4, tree4MaterialID);
  trees = min(trees, tree4);
  int tree5MaterialID;
  Tree treeData5 = Tree(vec3(-15.0, -9.0, -7.0),
                       0.6,0.5, // lower&upper radius
                       18.0, // tree hight
                       0.1, // tilt
                       vec2(5.0, 4.2), // canopy length
                       vec2(0.3, -0.01), // small trunk
                       vec2(15.0, 3.0));
  float tree5 = treeSDF(queryPos, treeData5, tree5MaterialID);
  trees = min(trees, tree5);
  int tree6MaterialID;
  Tree treeData6 = Tree(vec3(18.0, -9.0, -15.0),
                       0.6,0.5, // lower&upper radius
                       28.0, // tree hight
                       -0.1, // tilt
                       vec2(5.0, 4.2), // canopy length
                       vec2(0.3, -0.01), // small trunk
                       vec2(15.0, 3.0));
  float tree6 = treeTrunkOnlySDF(queryPos, treeData6, tree6MaterialID);
  trees = min(trees, tree6);

  if(trees == tree) treeMaterialID = tree1MaterialID;
  if(trees == tree2) treeMaterialID = tree2MaterialID;
  if(trees == tree3) treeMaterialID = tree3MaterialID;
  if(trees == tree4) treeMaterialID = tree4MaterialID;
  if(trees == tree5) treeMaterialID = tree5MaterialID;
  if(trees == tree6) treeMaterialID = tree6MaterialID;

  return trees;

  // treeMaterialID = tree1MaterialID;
  // return tree;
}

float carSDF(vec3 queryPos, out int carMaterialID){
  queryPos -= vec3(-2.3, -1.6, -19.0);
  //queryPos.z += tan(u_Time * 0.1);
  //queryPos.x += sin(queryPos.z*0.2 + 0.1);
  vec3 carUpPos = queryPos - vec3(0.0, -0.2, 0.0);
  float carUp = roundBoxSDF(carUpPos, vec3(1.0, 0.4, 1.5), 0.2);
  vec3 carDownPos = queryPos - vec3(0.0, -0.9, 0.0);
  float carDown = roundBoxSDF(carDownPos, vec3(1.4, 0.3, 2.0), 0.1);
  vec3 tire1Pos = queryPos - vec3(-0.9, -1.5, 1.0);
  tire1Pos = rotateZ(tire1Pos, 3.14159 * 0.5);
  float tire1 = roundedCylinderSDF(tire1Pos, 0.25, 0.25, 0.01);
  vec3 tire2Pos = queryPos - vec3(0.9, -1.5, 1.0);
  tire2Pos = rotateZ(tire2Pos, 3.14159 * 0.5);
  float tire2 = roundedCylinderSDF(tire2Pos, 0.25, 0.25, 0.01);
  vec3 light1Pos = queryPos - vec3(0.8, -0.9, 2.0);
  float light1 = sphereSDF(light1Pos, vec3(0.0,0.0,0.0), 0.25);
  vec3 light2Pos = queryPos - vec3(-0.8, -0.9, 2.0);
  float light2 = sphereSDF(light2Pos, vec3(0.0,0.0,0.0), 0.25);
  float car = min(carUp, carDown);
  car = min(car, tire1);
  car = min(car, tire2);
  car = min(car, light1);
  car = min(car, light2);
  carMaterialID = CAR_MATERIAL_ID;
  if(car == tire1 || car == tire2){
    carMaterialID = CAR_TIRE_MATERIAL_ID;
  }
  else if(car == light1 || car == light2){
    carMaterialID = CAR_LIGHT_MATERIAL_ID;
  }
  return car;
}

float sceneSDF(vec3 queryPos, out int material_id) 
{
  
  int terrianMaterialID;
  float terrain = terrainSDF(queryPos, terrianMaterialID);

  int roadMaterial = ROAD_MATERIAL_ID;
  float road = roadSDF(queryPos, roadMaterial);
  
  int treeMaterialID = 0;
  float trees = forestSDF(queryPos, treeMaterialID);

  int carMaterialID;
  float car = carSDF(queryPos, carMaterialID);
  
  float result = smoothUnion(trees, terrain, 0.7);
  result = min(road, result);
  result = min(car, result);
  float colorResult = min(trees, terrain);
  colorResult = min(road, colorResult);
  colorResult = min(car, colorResult);
  if(colorResult == trees){
      material_id = treeMaterialID;
  }
  else if(colorResult == terrain){
    material_id = terrianMaterialID;
  }
  else if(colorResult == road){
    material_id = roadMaterial;
  }
  else if(colorResult == car){
    material_id = carMaterialID;
  }
//material_id = 2;

  return result;
}

// ====== ray marching and scene function
Ray getRay(vec2 uv) 
{
    Ray ray;

    vec3 look = normalize(u_Ref - u_Eye);
    float len = length(u_Ref - u_Eye);
    vec3 camera_RIGHT = normalize(cross(look, u_Up));
    vec3 camera_UP = cross(camera_RIGHT, look);
    
    float aspect_ratio = u_Dimensions.x / u_Dimensions.y;
    vec3 screen_vertical = camera_UP * len * tan(FOV / 2.0); 
    vec3 screen_horizontal = camera_RIGHT * len * aspect_ratio * tan(FOV / 2.0);
    vec3 screen_point = (u_Ref + uv.x * screen_horizontal + uv.y * screen_vertical);
    
    ray.origin = u_Eye;
    ray.direction = normalize(screen_point - u_Eye);
    return ray;
}

// sdf gradient is the ray marching direction
// which is the estimated normal of the object 
vec3 getEstimatedNormal(vec3 p) {
    vec2 e = vec2(0.0001, 0);
    int useless_material_id;
    float x = sceneSDF(p + e.xyy, useless_material_id) - sceneSDF(p, useless_material_id);
    float y = sceneSDF(p + e.yxy, useless_material_id) - sceneSDF(p, useless_material_id);
    float z = sceneSDF(p + e.yyx, useless_material_id) - sceneSDF(p, useless_material_id);
    return normalize(abs(vec3(x, y, z)));
}

Intersection getRaymarchedIntersection(vec2 uv)
{
    Intersection intersection;

    Ray ray = getRay(uv);
    float distanceToSurface = 0.0;
    
    for (int i = 0; i < MAX_STEPS; ++i)
    {
      vec3 queryPoint = ray.origin + ray.direction * distanceToSurface;

      // if distance is too large, assume nothing hit, break ray marching
      if(distanceToSurface > MAX_DIST){
        break;
      }
      int material_id = 0;
      float distance = sceneSDF(queryPoint, material_id);
      // hit the object, create and return intersection
      if (distance < EPSILON)
      {  
        intersection.position = queryPoint;
        intersection.normal = getEstimatedNormal(queryPoint);
        intersection.distance = length(queryPoint - ray.origin);  
        //intersection.distance = -1.0; 
        intersection.material_id = material_id;
        return intersection;
      } 
      distanceToSurface += distance;   
    }

    // if not hit
    intersection.distance = -1.0;
    intersection.material_id = -1;
    intersection.position = vec3(uv, 0.0);
    return intersection;
}

// https://iquilezles.org/articles/rmshadows/
float softshadow(vec3 lightDir, vec3 origin, float mint, float k)
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 70; ++i)
    {
      int useless_material_id = 0;
      float h = sceneSDF(origin + lightDir * t, useless_material_id);
      if( h < 0.001 )
          return 0.0;
      res = min( res, k*h/t );
      t += h;
    }
    return res;
}


vec3 getSceneColor(vec2 uv)
{
  Intersection intersection = getRaymarchedIntersection(uv);

  float time = sin(u_Time*0.1);

  // calculate light
  vec3 lightPos = vec3(5.0, 17.0, -2.0);
  vec3 lightColor = vec3(1.0, 1.0, 1.0);
  vec3 l = normalize(lightPos - intersection.position);
  float lightingCol = clamp(dot(intersection.normal, l), 0.0, 1.0);
  vec3 color = vec3(lightingCol) * 2.0;

  vec3 diffuseColor;

  vec3 skyColor = vec3(247.0, 85.0, 50.0) / 255.0;
  //vec3 color;
  vec3 upperCol = mix(DAY_UPPER_COL, NIGHT_UPPER_COL, clamp(time, 0.0, 1.0));
  vec3 lowerCol = mix(DAY_LOWER_COL, NIGHT_LOWER_COL, clamp(time, 0.0, 1.0));

  vec3 lightDir = normalize(vec3(0.0, 2.0, -3.0));

  if(intersection.distance > 0.0){
    if(intersection.material_id == TERRAIN_MATERIAL_ID){
      color *= TERRAIN_COL;
    }
    else if(intersection.material_id == TERRAIN_SHADOW_MATERIAL_ID){
      float shadow = softshadow(lightDir, intersection.position, 0.1, 32.0);
      color *= TERRAIN_COL * shadow;
    }
    else if(intersection.material_id == TERRAIN2_MATERIAL_ID){
      color *= TERRAIN2_COL;
    }
    else if(intersection.material_id == TERRAIN3_MATERIAL_ID){
      color *= TERRAIN3_COL;
    }
    else if(intersection.material_id == TREE_MATERIAL_ID){
      color *= TREE_COL;
    }
    else if(intersection.material_id == TREE_TRUNK_MATERIAL_ID){
      color *= TREE_TRUNK_COL;
    }
    else if(intersection.material_id == ROAD_MATERIAL_ID){
      float shadow = softshadow(lightDir, intersection.position, 0.1, 32.0);
      color *= ROAD_COL * shadow;
    }
    else if(intersection.material_id == ROAD_MIDDLE_MATERIAL_ID){
      color *= ROAD_MIDDLE_COL;
    }
    else if(intersection.material_id == CAR_MATERIAL_ID){
      color *= CAR_COL;
    }
    else if(intersection.material_id == CAR_TIRE_MATERIAL_ID){
      color *= CAR_TIRE_COL;
    }
    else if(intersection.material_id == CAR_LIGHT_MATERIAL_ID){
      color *= CAR_LIGHT_COL;
    }
    vec3 DAY_LIGHT = vec3(247.0, 229.0, 141.0)/ 255.0;
    vec3 NIGHT_LIGHT = vec3(205.0, 243.0, 247.0)/ 255.0;
    vec3 ambientColor = mix(DAY_LIGHT, NIGHT_LIGHT, clamp(time, 0.0, 1.0));
    color += ambientColor * 0.15;
  }
  else{
    float interpolateValue = bias(intersection.position.y, 0.32);
    color = mix(lowerCol, upperCol, interpolateValue);
    //diffuseColor =  mix(lowerCol, upperCol, interpolateValue);
    
    vec2 newUV = vec2(uv.x * 1.8, uv.y) *5.0;
    newUV += vec2(0.0, clamp(time, 0.0, 1.0) - 1.0);
    float sun = sdCircle(newUV, 1.5);
    vec3 sunCol = vec3(247.0, 96.0, 2.0) / 255.0;
    if(sun < -1.0)
    {
      color = (sunCol + sunCol);
    }
    else if (sun >= -1.0 && sun <= 0.0){
      float sunT = smoothstep(-1.0, 0.0, sun);
      color = mix(sunCol + sunCol, color,  sunT);
    } 
  }

  float fogT = smoothstep(160.0, 190.0, intersection.distance);
  fogT = min(fogT, 0.5);
  color = mix(color, lowerCol, fogT);

  // // blinn-phong
  // float shininess = 16.0;
  // vec3 ambientColor = diffuseColor * 0.2;
  // const float lightPower = 240.0;
  // const vec3 specColor = vec3(1.0, 1.0, 1.0);

  // vec3 normal = normalize(intersection.normal);
  // vec3 lightDir = lightPos - intersection.position;
  // float distance = length(lightDir);
  // distance = distance * distance;
  // lightDir = normalize(lightDir);

  // float lambertian = clamp(dot(lightDir, normal), 0.0, 1.0);
  // float specular = 0.0;

  // vec3 viewDir = normalize(u_Eye - intersection.position);

  // // this is blinn phong
  // vec3 halfDir = normalize(lightDir + viewDir);
  // float specAngle = max(dot(halfDir, normal), 0.0);
  // specular = pow(specAngle, shininess);
  
  // vec3 colorLinear = diffuseColor * lambertian * lightColor * lightPower / distance +
  //                    specColor * specular * lightColor * lightPower / distance + 
  //                    ambientColor;
  // // apply gamma correction (assume ambientColor, diffuseColor and specColor
  // // have been linearized, i.e. have no gamma correction in them)
  // vec3 colorGammaCorrected = pow(colorLinear, vec3(1.0 / 2.2));


  //color = vec3(intersection.distance);
  //return colorGammaCorrected + colorGammaCorrected*0.5;
  return color;
}

void main() {
  vec3 col = getSceneColor(fs_Pos.xy);
  out_Col = vec4(col, 1.0);
}

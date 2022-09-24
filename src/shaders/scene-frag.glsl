#version 300 es
precision highp float;

#define MAX_RAY_STEPS (128)
#define EPSILON (1e-2)

uniform vec3 u_Eye, u_Ref, u_Right, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const float tanFovY2 = tan(radians(45.0) / 2.0);

// =================================
// SDF OPERATIONS
// =================================

float sdfUnion(float d1, float d2) {
  return min(d1, d2);
}

float sdfIntersect(float d1, float d2) {
  return max(d1, d2);
}

float sdfSubtract(float d1, float d2) {
  return max(d1, -d2);
}

float smoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h); 
}

float smoothSubtraction(float d1, float d2, float k) 
{
  float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0 );
  return mix(d2, -d1, h) + k * h * (1.0 - h); 
}

float smoothIntersection(float d1, float d2, float k)
{
  float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) + k * h * (1.0 - h);
}

// =================================
// SDF PRIMITIVES
// =================================

float planeSDF(vec3 pos, float height) {
  return pos.y - height;
}

float sphereSDF(vec3 pos, vec3 center, float radius) {
  return distance(pos, center) - radius;
}

// =================================
// SCENE
// =================================

float sceneSDF(vec3 pos) {
  // return sphereSDF(pos, vec3(0), 1.0);
  return planeSDF(pos, -2.0);
  // return sdfUnion(planeSDF(pos, -2.0), sphereSDF(pos, vec3(0), 1.0));
}

// =================================
// CAMERA
// =================================

vec3 getRay(vec2 ndc) {
  float len = distance(u_Ref, u_Eye) * tanFovY2;
  vec3 H = normalize(cross(u_Up, u_Ref - u_Eye));
  vec3 V = normalize(cross(H, u_Eye - u_Ref));
  vec3 p = u_Ref 
    + ndc.x * H * len * u_Dimensions.x / u_Dimensions.y 
    + ndc.y * V * len;
  return normalize(p - u_Eye);
}

struct Intersection {
  vec3 pos;
  float dist;
};

Intersection rayMarch(vec2 ndc) {
  vec3 ray = getRay(ndc);
  Intersection intersection;

  vec3 currentPos = u_Eye;
  for (int i = 0; i < MAX_RAY_STEPS; ++i) {
    float distToSurface = sceneSDF(currentPos);

    if (distToSurface < EPSILON) {
      intersection.pos = currentPos;
      intersection.dist = distance(currentPos, u_Eye);
      return intersection;
    }

    currentPos += ray * distToSurface;
  }

  intersection.dist = -1.0;
  return intersection;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

vec3 getSkyColor(vec2 ndc) {
  return vec3(135.0, 206.0, 235.0) / 255.0;
}

const vec3 vecToLight = normalize(vec3(1, 1, 0));

vec3 getColor(vec2 ndc) {
  Intersection isect = rayMarch(ndc);

  if (isect.dist > 0.0) {
    vec3 nor = estimateNormal(isect.pos);

    return vec3(1, 0, 0) * max(0.0, dot(nor, vecToLight));
  } else {
    return getSkyColor(ndc);
  }
}

void main() {
  out_Col = vec4(getColor(fs_Pos), 1);
  // out_Col = vec4(getRay(fs_Pos), 1);
}

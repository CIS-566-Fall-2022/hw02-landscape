#version 300 es
precision highp float;

#define MAX_RAY_STEPS (128)
#define MAX_DISTANCE (512.0)
#define EPSILON (1e-2)

#define FBM_OCTAVES (4)
#define FBM_OCTAVES_SDF (4)

uniform vec3 u_Eye, u_Ref, u_Right, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const float tanFovY2 = tan(radians(45.0) / 2.0);

// =================================
// NOISE
// =================================

float random1(float p) {
  return fract(sin(p * 592.4) * 102934.239);
}

vec3 random3(vec3 p) {
  return fract(sin(vec3(dot(p, vec3(185.3, 563.9, 887.2)),
                        dot(p, vec3(593.1, 591.2, 402.1)),
                        dot(p, vec3(938.2, 723.4, 768.9))
                  )) * 58293.492);
}

vec4 random4(vec4 p) {
  return fract(sin(vec4(dot(p, vec4(127.1, 311.7, 921.5, 465.8)),
                        dot(p, vec4(269.5, 183.3, 752.4, 429.1)),
                        dot(p, vec4(420.6, 631.2, 294.3, 910.8)),
                        dot(p, vec4(213.7, 808.1, 126.8, 572.0))
                  )) * 43758.5453);
}

float surflet(float p, float gridPoint) {
  float t2 = abs(p - gridPoint);
  float t = 1.f - 6.f * pow(t2, 5.f) + 15.f * pow(t2, 4.f) - 10.f * pow(t2, 3.f);
  float gradient = random1(gridPoint) * 2. - 1.;
  float diff = p - gridPoint;
  float height = diff * gradient;
  return height * t;
}

float surflet(vec3 p, vec3 gridPoint) {
  vec3 t2 = abs(p - gridPoint);
  vec3 t = vec3(1.f) - 6.f * pow(t2, vec3(5.f)) + 15.f * pow(t2, vec3(4.f)) - 10.f * pow(t2, vec3(3.f));
  vec3 gradient = random3(gridPoint) * 2. - vec3(1.);
  vec3 diff = p - gridPoint;
  float height = dot(diff, gradient);
  return height * t.x * t.y * t.z;
}

float surflet(vec4 p, vec4 gridPoint) {
  vec4 t2 = abs(p - gridPoint);
  vec4 t = vec4(1.f) - 6.f * pow(t2, vec4(5.f)) + 15.f * pow(t2, vec4(4.f)) - 10.f * pow(t2, vec4(3.f));
  vec4 gradient = random4(gridPoint) * 2. - vec4(1.);
  vec4 diff = p - gridPoint;
  float height = dot(diff, gradient);
  return height * t.x * t.y * t.z * t.w;
}

float perlin(float p) {
	float surfletSum = 0.f;
	for (int dx = 0; dx <= 1; ++dx) {
    surfletSum += surflet(p, floor(p) + float(dx));
	}
	return surfletSum;
}

float perlin(vec3 p) {
	float surfletSum = 0.f;
	for (int dx = 0; dx <= 1; ++dx) {
		for (int dy = 0; dy <= 1; ++dy) {
			for (int dz = 0; dz <= 1; ++dz) {
        surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

float perlin(vec4 p) {
	float surfletSum = 0.f;
	for (int dx = 0; dx <= 1; ++dx) {
		for (int dy = 0; dy <= 1; ++dy) {
			for (int dz = 0; dz <= 1; ++dz) {
        for (int dw = 0; dw <= 1; ++dw) {
          surfletSum += surflet(p, floor(p) + vec4(dx, dy, dz, dw));
        }
			}
		}
	}
	return surfletSum;
}

float perlin(vec3 p, float t) {
  return perlin(vec4(p, t));
}

float fbm(vec4 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < FBM_OCTAVES; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

float fbm(vec3 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < FBM_OCTAVES; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

float fbm(vec3 p, float t) {
  return fbm(vec4(p, t));
}

struct WorleyInfo {
  float dist;
  vec3 color;
};

WorleyInfo worley(vec4 uv) {
  vec4 uvInt = floor(uv);
  vec4 uvFract = uv - uvInt;
  float minDist = 1.0f;
  vec3 color;
  for (int x = -1; x <= 1; ++x) {
    for (int y = -1; y <= 1; ++y) {
      for (int z = -1; z <= 1; ++z) {
        for (int w = -1; w <= 1; ++w) {
          vec4 neighbor = vec4(float(x), float(y), float(z), float(w));
          vec4 point = random4(uvInt + neighbor);
          vec4 diff = neighbor + point - uvFract;
          float dist = length(diff);
          if (dist < minDist) {
            minDist = dist;
            color = random4(point).rgb;
          }
        }
      }
    }
  }
  WorleyInfo worleyInfo;
  worleyInfo.dist = minDist;
  worleyInfo.color = color;
  return worleyInfo;
}

WorleyInfo worley(vec3 p, float t) {
  return worley(vec4(p, t));
}

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

float sdfSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h); 
}

float sdfSmoothSubtraction(float d1, float d2, float k)
{
  float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0 );
  return mix(d2, -d1, h) + k * h * (1.0 - h); 
}

float sdfSmoothIntersection(float d1, float d2, float k)
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

float capsuleSDF(vec3 pos, vec3 a, vec3 b, float r) {
  vec3 pa = pos - a;
  vec3 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

// =================================
// SCENE
// =================================

float sceneSDF(vec3 pos) {
  return planeSDF(pos, -15.0 + perlin(pos * 0.05) * 12.0 + perlin(pos * 0.01) * 30.0);
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
  float distTraveled = 0.0;
  for (int i = 0; i < MAX_RAY_STEPS; ++i) {
    float distToSurface = sceneSDF(currentPos);

    float epsilonMultiplier = 100.0 * (distTraveled / MAX_DISTANCE) + 1.0;
    if (distToSurface < EPSILON * epsilonMultiplier) {
      intersection.pos = currentPos;
      intersection.dist = distTraveled;
      return intersection;
    }

    currentPos += ray * distToSurface;
    distTraveled += distToSurface;

    if (distTraveled > MAX_DISTANCE) {
      break;
    }
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
}

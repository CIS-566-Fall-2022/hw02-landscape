#version 300 es
precision highp float;

#define FOV_Y_DEGREES 55.0

#define MAX_RAY_STEPS 128
#define MAX_DISTANCE 1024.0
#define EPSILON 1e-2

uniform vec3 u_Eye, u_Ref, u_Right, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const float tanFovY2 = tan(radians(FOV_Y_DEGREES) / 2.0);

// =================================
// MATH
// =================================

float bias(float b, float t) {
  return pow(t, log(b) / log(0.5));
}

float gain(float g, float t) {
  if (t < 0.5) {
    return bias(1.0 - g, 2.0 * t) / 2.0;
  } else {
    return 1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0;
  }
}

// =================================
// NOISE
// =================================

float random1(float p) {
  return fract(sin(p * 592.4) * 102934.239);
}

vec2 random2(vec2 p) {
  return fract(sin(vec2(dot(p, vec2(602.3, 448.9)),
                        dot(p, vec2(192.4, 672.6))
                  )) * 48123.492);
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

float surflet(vec2 p, vec2 gridPoint) {
  vec2 t2 = abs(p - gridPoint);
  vec2 t = vec2(1.f) - 6.f * pow(t2, vec2(5.f)) + 15.f * pow(t2, vec2(4.f)) - 10.f * pow(t2, vec2(3.f));
  vec2 gradient = random2(gridPoint) * 2. - vec2(1.);
  vec2 diff = p - gridPoint;
  float height = dot(diff, gradient);
  return height * t.x * t.y;
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

float perlin(vec2 p) {
	float surfletSum = 0.f;
	for (int dx = 0; dx <= 1; ++dx) {
		for (int dy = 0; dy <= 1; ++dy) {
      surfletSum += surflet(p, floor(p) + vec2(dx, dy));
		}
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

float fbm(vec2 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < octaves; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

const mat2 fbmRotateMat = mat2(
  0.8, 0.6,
  -0.6, 0.8
);

float fbmRotate(vec2 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < octaves; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p = 2.0 * fbmRotateMat * p;
    amplitude *= 0.5;
  }
  return value;
}

float fbm(vec3 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < octaves; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

float fbm(vec4 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < octaves; ++i) {
    value += amplitude * ((perlin(p) + 1.0) / 2.0);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

struct WorleyInfo {
  float dist;
  vec3 color;
};

float worley(vec2 uv) {
  vec2 uvInt = floor(uv);
  vec2 uvFract = uv - uvInt;
  float minDist = 1.0f;
  for (int x = -1; x <= 1; ++x) {
    for (int y = -1; y <= 1; ++y) {
      vec2 neighbor = vec2(float(x), float(y));
      vec2 point = random2(uvInt + neighbor);
      vec2 diff = neighbor + point - uvFract;
      minDist = min(minDist, length(diff));
    }
  }
  return minDist;
}

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

const float terrainOffset = -90.0;
const float terrainAmplitude = 100.0;
const float terrainMaxHeight = terrainOffset + terrainAmplitude;
const float waterHeight = -48.0;

struct Terrain {
  float dist;
  int material;
};

Terrain sceneSDF(vec3 pos) {
  float mountainsNoise = fbmRotate(pos.xz * 0.02, 8);
  float mountainsSDF = planeSDF(pos, terrainOffset + mountainsNoise * terrainAmplitude);
  float waterSDF = planeSDF(pos, waterHeight);

  if (mountainsSDF < waterSDF) {
    return Terrain(mountainsSDF, 1);
  } else {
    return Terrain(waterSDF, 2);
  }
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
  float t;
  int material;
};

Intersection rayMarch(vec3 dir) {
  Intersection intersection;

  vec3 currentPos = u_Eye;
  float t = 0.0;
  for (int i = 0; i < MAX_RAY_STEPS; ++i) {
    Terrain terrain = sceneSDF(currentPos);
    float distToSurface = terrain.dist;

    float epsilonMultiplier = 100.0 * (t / MAX_DISTANCE) + 1.0;
    if (distToSurface < EPSILON * epsilonMultiplier) {
      intersection.pos = currentPos;
      intersection.t = t;
      intersection.material = terrain.material;
      return intersection;
    }

    currentPos += dir * distToSurface;
    t += distToSurface;

    if (t > MAX_DISTANCE) {
      break;
    }
  }

  intersection.t = -1.0;
  return intersection;
}

vec3 estimateNormal(vec3 p) {
  return normalize(vec3(
    sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).dist - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).dist,
    sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).dist - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).dist,
    sceneSDF(vec3(p.x, p.y, p.z + EPSILON)).dist - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).dist
  ));
}

struct DirectionalLight {
  vec3 vecToLight;
  vec3 color;
};

#define SUNLIGHT_COLOR vec3(1.0, 0.93, 0.89)
#define FILL_LIGHT_COLOR vec3(0.53, 0.81, 0.92)

const DirectionalLight[3] lights = DirectionalLight[3](
  DirectionalLight(normalize(vec3(0, 0.8, 1)), SUNLIGHT_COLOR * 1.2), // key
  DirectionalLight(normalize(vec3(0, 1, 0)), FILL_LIGHT_COLOR * 0.5), // fill
  DirectionalLight(normalize(vec3(-1.5, 0, 1)), SUNLIGHT_COLOR * 0.6) // fake GI
);

const float shadowK = 1.1;

float softShadow(vec3 p) {
  const vec3 rayDirection = lights[0].vecToLight;
  float t = 0.1;
  vec3 currentPos = p + t * rayDirection;

  float result = 1.0;
  float prevH = 1e20;
  while (currentPos.y < terrainMaxHeight) {
    float h = sceneSDF(currentPos).dist;
    if (h < EPSILON) {
      return 0.0;
    }

    float y = (h * h) / (2.0 * prevH);
    float d = sqrt(h * h - y * y);

    result = min(result, shadowK * d / max(0.0, t - y));
    t += h;
    currentPos = p + t * rayDirection;
  }

  return result;
}

const float cloudsHeight = 110.0;

float cloudCoverage(vec3 p, vec3 dir) {
  // assumes camera is below clouds
  if (dir.y < 0.05) {
    return 0.0;
  }

  float t = (cloudsHeight - p.y) / dir.y;
  vec3 cloudsPos = p + dir * t;
  cloudsPos.z += 1.2 * u_Time;
  float cloudsFBM = fbm(vec3(cloudsPos.xz * 0.01, u_Time / 150.0), 6);
  return smoothstep(0.4, 0.8, cloudsFBM);
}

const vec3 waterColor1 = vec3(35.0, 137.0, 218.0) / 255.0 * 0.5;
const vec3 waterColor2 = vec3(28.0, 163.0, 236.0) / 255.0 * 0.7;
const vec3 rockColor1 = vec3(145.0) / 255.0 * 0.4;
const vec3 rockColor2 = vec3(89.0, 96.0, 97.0) / 255.0;
const vec3 snowColor = vec3(219.0, 241.0, 253.0) / 255.0;

vec3 getTerrainColor(vec3 pos, vec3 nor, int material) {
  vec3 finalColor;

  if (material == 1) {
    float rockNoise = fbm(pos / 5.0 + perlin(pos) * 0.5, 4);
    rockNoise = smoothstep(0.3, 0.7, rockNoise);
    rockNoise = gain(0.9, rockNoise);
    vec3 rockColor = mix(rockColor1, rockColor2, rockNoise);

    float snowSlopeFactor = smoothstep(0.83, 0.75, dot(nor, vec3(0, 1, 0)));

    finalColor = mix(rockColor, snowColor, smoothstep(-38.0, -35.0, pos.y) * snowSlopeFactor);
  } else {
    float waterNoise = perlin(pos * 0.05);
    finalColor = mix(waterColor1, waterColor2, waterNoise);
  }

  return finalColor;
}

const vec3 skyColor1 = vec3(214.0, 242.0, 255.0) / 255.0;
const vec3 skyColor2 = vec3(175.0, 212.0, 255.0) / 255.0;

vec3 getSkyColor(vec3 dir) {
  float perturb = fbm(dir * 10.0, 4);
  float cells = worley(dir * 10.0 + vec3(perturb * 10.0), u_Time / 100.0).dist;
  cells = (cells * 2.0) - 1.0;

  float gradientFactor = smoothstep(-0.1, 0.5, dir.y);
  gradientFactor += (cells * 0.2);
  return mix(skyColor1, skyColor2, gradientFactor);
}

const vec3 cloudsColor = vec3(1.05);

vec3 getColor(vec2 ndc) {
  vec3 cameraRay = getRay(ndc);
  Intersection isect = rayMarch(cameraRay);

  if (isect.t > 0.0) {
    vec3 nor = estimateNormal(isect.pos);

    vec3 finalColor = vec3(0);
    float totalShadow = min(1.0, softShadow(isect.pos) 
        + smoothstep(0.4, 0.2, cloudCoverage(isect.pos, lights[0].vecToLight)));
    finalColor += lights[0].color * max(0.0, dot(nor, lights[0].vecToLight)) 
        * mix(0.35, 1.0, totalShadow);
    for (int i = 1; i < 3; ++i) {
      finalColor += lights[i].color * max(0.0, dot(nor, lights[i].vecToLight));
    }
    finalColor *= getTerrainColor(isect.pos, nor, isect.material);

    float lambda = exp(-0.0025 * isect.t);
    finalColor = mix(getSkyColor(cameraRay), finalColor, lambda);

    return finalColor;
  } else {
    vec3 skyColor = getSkyColor(cameraRay);
    float clouds = cloudCoverage(u_Eye, cameraRay);

    return mix(skyColor, cloudsColor, clouds);
  }
}

void main() {
  out_Col = vec4(getColor(fs_Pos), 1);
}

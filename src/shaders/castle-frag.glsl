#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

#define PI 3.1415927
#define TWO_PI 6.2831853


#define MAX_RAY_STEPS 156
#define EPSILON_P 0.25f
#define EPSILON_N 0.001f
//#define MULTISAMPLE
#define SPP 1

#define MAX_WORLD_BOUNDS 50

#define MAT_RIVER 0
#define MAT_BRIDGE 1
#define MAT_LEFT_HILL 2
#define MAT_RIGHT_HILL 3
#define MAT_RIGHT_CLIFFS 4
#define MAT_RIGHT_HILL_2 5
#define MAT_RIGHT_MOUNTAINS 6
#define MAT_CASTLE 7

struct Ray {
  vec3        o;
  vec3        d;
};

struct Material {
  vec3 albedo;
};

struct Intersection {
  vec3        p;
  vec2        uv;
  float       t;
  vec3        n;
  float       distance_to_surface;
  int         obj_ID;
  int         inst_ID;
  int         material_ID;
};

struct DirectionalLight
{
    vec3      dir;
    vec3      col;
};

struct Sun {
  vec3 p; // this is technically "incoming ray direction"
  float r_core;
  vec3 col_core;
  float r_corona;
  vec3 col_corona;
  DirectionalLight sunlight;
};

const DirectionalLight light = DirectionalLight(  normalize(vec3(-1,-1,-1)), 
                                                  vec3(1.0f, 1.0f, 1.0f)
                                                );

const Material material = Material(vec3(0.05f, 0.85f, 0.92f));

const DirectionalLight fill_light = DirectionalLight(normalize(vec3(0, 1, 0)), vec3(.75, .39, .14));
const DirectionalLight gi_light = DirectionalLight(normalize(vec3(-5.0, 0, -5.0)), vec3(.31, .07, .02));

const Sun sun = Sun(vec3(-500.00f, 185.0f, 1000.0f), 1.0f, vec3(1.0f, 0.95f, 0.5f), 6.0f, vec3(1.91f, 1.373f, 0.95f), DirectionalLight(normalize(-vec3(-500.00f, 185.0f, 1000.0f)), vec3(0.75f, 0.55f, 0.12f)));

/////////////////////////////////////////////////////////////////////////////////////////////////
// 3D FBM implementation
//
// Based on Adam's 560 slides

float random3D_to_float_fbm( vec3 input_vals ) {
	return fract(sin(dot(input_vals, vec3(2114.11f, 1298.46f, 598.25f))) * 51034.13f);
}

float interpolate3D_cubic( vec3 input_vals ) {
    vec3 input_fract = fract(input_vals);
	vec3 input_floor = floor(input_vals);
	
	// generate the random values associated with the 8 points on our grid
	float bottom_left_front = random3D_to_float_fbm(input_floor);
	float bottom_left_back = random3D_to_float_fbm(input_floor + vec3(0,0,1));
	float bottom_right_front = random3D_to_float_fbm(input_floor + vec3(1,0,0));
	float bottom_right_back = random3D_to_float_fbm(input_floor + vec3(1,0,1));
	float top_left_front = random3D_to_float_fbm(input_floor + vec3(0,1,0));
	float top_left_back = random3D_to_float_fbm(input_floor + vec3(0,1,1));
	float top_right_front = random3D_to_float_fbm(input_floor + vec3(1,1,0));
	float top_right_back = random3D_to_float_fbm(input_floor + vec3(1,1,1));

	float t_x = smoothstep(0.0, 1.0, input_fract.x);
	float t_y = smoothstep(0.0, 1.0, input_fract.y);
	float t_z = smoothstep(0.0, 1.0, input_fract.z);

    float interpX_bottom_front = mix(bottom_left_front, bottom_right_front, t_x);
    float interpX_bottom_back = mix(bottom_left_back, bottom_right_back, t_x);
    float interpX_top_front = mix(top_left_front, top_right_front, t_x);
    float interpX_top_back = mix(top_left_back, top_right_back, t_x);

    float interpY_front = mix(interpX_bottom_front, interpX_top_front, t_y);
    float interpY_bottom = mix(interpX_bottom_back, interpX_top_back, t_y);

    return mix(interpY_front, interpY_bottom, t_z);
}

float fbm3D( vec3 p, float amp, float freq, float persistence, int octaves ) {
    float sum = 0.0;
    for(int i = 0; i < octaves; ++i) {
        sum += interpolate3D_cubic(p * freq) * amp;
        amp *= persistence;
        freq *= 2.0;
    }
    return sum;
}

/////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////
// 3D Worley Noise implementation
//
// Based on Adam's 560 slides

vec3 random3D_to_3D_worley( vec3 input_vals ) {
    return fract(
		sin(
			vec3(
				dot(
					input_vals, vec3(136.38, 564.45, 853.345)
				),
                dot(
					input_vals, vec3(522.5, 635.53, 211.34)
				),
				dot(
					input_vals, vec3(363.63, 755.69, 892.35)
				)
			)
		) * 58387.3569
	);
}


float worley3D( vec3 p, float freq ) {
	// scale input by freq to increase size of grid
    p *= freq;

    vec3 p_floor = floor(p);
    vec3 p_fract = fract(p);
    float min_d = 1.0;

  // look for closest voronoi centroid point in 3x3x3 grid around current position
	for (int z = -1; z <= 1; ++z) {
		for	(int y = -1; y <= 1; ++y) {
			for	(int x = -1; x <= 1; ++x) {

				vec3 this_neighbor = vec3(float(x), float(y), float(z));

        // voronoi centroid
				vec3 neighbor_point = random3D_to_3D_worley(p_floor + this_neighbor);

				vec3 diff = this_neighbor + neighbor_point - p_fract;

				float d = length(diff);

				min_d = min(min_d, d);
			}
		}
	}
    
    return min_d;
}

/////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////
// Toolbox Function implementations

float bias(float t, float b) {
    return (t / ((((1.0/b) - 2.0)*(1.0 - t))+1.0));
}

float gain(float t, float g) {
    if (t < 0.5f) {
		return bias(1.0f - g, 2.0f * t) / 2.0f;
	}
	else {
		return 1.0 - bias(1.0f - g, 2.0 - 2.0 * t) / 2.0f;
	}
}

float tri_wave(float x, float freq, float amp) {
    return abs(mod(x * freq, amp) - (0.5 * amp));
}


/////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////
// Procedural Color implementations

// https://iquilezles.org/articles/palettes/
vec3 getCosinePaletteColor(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
    return a + b * cos(TWO_PI * (c * t + d));
}
		
/////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////
// SDF toolbox implementations

// Most taken from https://iquilezles.org/articles/distfunctions/
float smoothUnion_SDF( float sdf_0, float sdf_1, float t ) {
    float h = clamp( 0.5 + 0.5*(sdf_1-sdf_0)/t, 0.0, 1.0 );
    return mix( sdf_1, sdf_0, h ) - t*h*(1.0-h);
}

float sphere_SDF(vec3 p, vec3 c, float r) {
    return length(p - c) - r;
}

float box_round_SDF( vec3 p, vec3 c, vec3 s, float r )
{
  vec3 q = abs(p - c) - s;
  return length(max(q, 0.0f)) + min(max(q.x,max(q.y,q.z)), 0.0f) - r;
}

float plane_SDF( vec3 p, vec3 n, float h )
{
  return dot(p, n) + h;
}

float cylinder_rounded_SDF( vec3 p, vec3 c, float ra, float rb, float h )
{
  vec3 q = p - c;
  vec2 d = vec2( length(q.xz)-2.0*ra+rb, abs(q.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float repeat_SDF(vec3 p, vec3 c) {
  vec3 q = mod(p,c) - 0.5f * c;
  return sphere_SDF(q, vec3(0.0f, -5.0f, 0.0f), 1.0f);
}

float repeat_bridge_SDF_0(vec3 p, vec3 c) {
  vec3 q = mod(p,c) - 0.5f * c;
  return box_round_SDF(q, vec3(0,0,0), vec3(3.0f, 4.0f, 0.75f), 0.5f);
}

float repeat_bridge_SDF_1(vec3 p, vec3 c) {
  vec3 q = mod(p,c) - 0.5f * c;
  return box_round_SDF(q, vec3(0,0,0), vec3(1.0f, 4.0f, 0.75f), 0.5f);
}
		
/////////////////////////////////////////////////////////////////////////////////////////////////       

float hyrule_castle_SDF (vec3 p, vec3 c)  {
  float castle_sdf = 0.0f;
  vec3 q = p - c;
  // center tower
  float center_tower_base = cylinder_rounded_SDF(q, c + vec3(0,-23.0f,0), 25.5f, 2.5f, 28.0f);
  float center_tower_mid = cylinder_rounded_SDF(q, c + vec3(0,30.0f,0), 20.5f, 2.5f, 20.0f);
  castle_sdf = smoothUnion_SDF(center_tower_base,center_tower_mid, 20.0f);

  float center_tower_spires[5];
  center_tower_spires[0] = cylinder_rounded_SDF(q, vec3(c + vec3(15.0f, 65.0f,15.0f)), 4.5f, 2.5f, 15.0f);
  center_tower_spires[1] = cylinder_rounded_SDF(q, vec3(c + vec3(-15.0f,65.0f,15.0f)), 4.5f, 2.5f, 15.0f);
  center_tower_spires[2] = cylinder_rounded_SDF(q, vec3(c + vec3(15.0f,65.0f,-15.0f)), 4.5f, 2.5f, 15.0f);
  center_tower_spires[3] = cylinder_rounded_SDF(q, vec3(c + vec3(-15.0f,65.0f,-15.0f)), 4.5f, 2.5f, 15.0f);
  center_tower_spires[4] = cylinder_rounded_SDF(q, vec3(c + vec3(0.0f,80.0f,0.0f)), 7.5f, 2.5f, 30.0f);

  float tippy_top = cylinder_rounded_SDF(q, vec3(c + vec3(0.0f,120.0f,0.0f)), 4.5f, 2.5f, 30.0f);
  castle_sdf = min(castle_sdf, tippy_top);

  // four wings
  float wings[4];
  wings[0] = cylinder_rounded_SDF(q, vec3(c + vec3(60.0f,-20.0f,60.0f)), 5.5f, 2.5f, 30.0f);
  wings[1] = cylinder_rounded_SDF(q, vec3(c + vec3(-60.0f,-20.0f,60.0f)), 5.5f, 2.5f, 30.0f);
  wings[2] = cylinder_rounded_SDF(q, vec3(c + vec3(60.0f,-20.0f,-60.0f)), 5.5f, 2.5f, 30.0f);
  wings[3] = cylinder_rounded_SDF(q, vec3(c + vec3(-60.0f,-20.0f,-60.0f)), 5.5f, 2.5f, 30.0f);

  // backtower
  float back_tower = cylinder_rounded_SDF(q, vec3(c + vec3(0.0f,-20.0f,60.0f)), 4.5f, 2.5f, 37.5f);
  castle_sdf = min(castle_sdf, back_tower);

  // 16 bridge-like towers
  float bridgelike_towers[16];
  bridgelike_towers[0] = cylinder_rounded_SDF(q, vec3(c + vec3(-120.0f,-30.0f,20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[1] = cylinder_rounded_SDF(q, vec3(c + vec3(-120.0f,-30.0f,-20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[2] = cylinder_rounded_SDF(q, vec3(c + vec3(120.0f,-30.0f,20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[3] = cylinder_rounded_SDF(q, vec3(c + vec3(120.0f,-30.0f,-20.0f)), 5.5f, 2.5f, 20.0f);
  
  bridgelike_towers[4] = cylinder_rounded_SDF(q, vec3(c + vec3(-20.0f,-30.0f,-120.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[5] = cylinder_rounded_SDF(q, vec3(c + vec3(20.0f,-30.0f,-120.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[6] = cylinder_rounded_SDF(q, vec3(c + vec3(-20.0f,-30.0f,120.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[7] = cylinder_rounded_SDF(q, vec3(c + vec3(20.0f,-30.0f,120.0f)), 5.5f, 2.5f, 20.0f);


  bridgelike_towers[8] = cylinder_rounded_SDF(q, vec3(c + vec3(-180.0f,-50.0f,20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[9] = cylinder_rounded_SDF(q, vec3(c + vec3(-180.0f,-50.0f,-20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[10] = cylinder_rounded_SDF(q, vec3(c + vec3(180.0f,-50.0f,20.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[11] = cylinder_rounded_SDF(q, vec3(c + vec3(180.0f,-50.0f,-20.0f)), 5.5f, 2.5f, 20.0f);

  bridgelike_towers[12] = cylinder_rounded_SDF(q, vec3(c + vec3(-20.0f,-50.0f,-180.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[13] = cylinder_rounded_SDF(q, vec3(c + vec3(20.0f,-50.0f,-180.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[14] = cylinder_rounded_SDF(q, vec3(c + vec3(-20.0f,-50.0f,180.0f)), 5.5f, 2.5f, 20.0f);
  bridgelike_towers[15] = cylinder_rounded_SDF(q, vec3(c + vec3(20.0f,-50.0f,180.0f)), 5.5f, 2.5f, 20.0f);

  // for corners of four wings


  for (int i = 0; i < 4; ++i) {
    castle_sdf = min(castle_sdf, wings[i]);
  }
  for (int i = 0; i < 16; ++i) {
    castle_sdf = min(castle_sdf, bridgelike_towers[i]);
  }
  for (int i = 0; i < 4; ++i) {
    float smooth_spire = smoothUnion_SDF(center_tower_spires[4], center_tower_spires[i], 5.0f);
    castle_sdf = min(castle_sdf, smooth_spire);
  }
  return castle_sdf;
}

float scene_SDF(out Intersection isect) {
  float min_distance = 10000.0f;


  vec3 castle_pos = vec3(-150,13.0f,400);
  
  float castle_bounding_sphere = sphere_SDF(isect.p, castle_pos, 750.0f);
  
  if (castle_bounding_sphere < min_distance) {
    float fbm_val = fbm3D(isect.p, 1.0f, 0.01f, 0.5f, 4) * 0.5f;
    float castle = hyrule_castle_SDF(isect.p + vec3(fbm_val, fbm_val, fbm_val), castle_pos);
    if (castle < min_distance) {
      min_distance = castle;
      isect.material_ID = MAT_CASTLE;
    }
  }
  return min_distance;
}

void getNormal_SDF(out Intersection isect) {
    Intersection isect_neighbors_pos = isect;
    Intersection isect_neighbors_neg = isect;

    isect_neighbors_pos.p.x = isect.p.x + EPSILON_N;
    isect_neighbors_neg.p.x = isect.p.x - EPSILON_N;
    float dx = scene_SDF(isect_neighbors_pos) - scene_SDF(isect_neighbors_neg);
    isect_neighbors_pos = isect;
    isect_neighbors_neg = isect;
    isect_neighbors_pos.p.y = isect.p.y + EPSILON_N;
    isect_neighbors_neg.p.y = isect.p.y - EPSILON_N;
    float dy = scene_SDF(isect_neighbors_pos) - scene_SDF(isect_neighbors_neg);
    isect_neighbors_pos = isect;
    isect_neighbors_neg = isect;
    isect_neighbors_pos.p.z = isect.p.z + EPSILON_N;
    isect_neighbors_neg.p.z = isect.p.z - EPSILON_N;
    float dz = scene_SDF(isect_neighbors_pos) - scene_SDF(isect_neighbors_neg);

    isect.n = normalize(vec3(dx, dy, dz));
}

bool sphereMarch(Ray r, out Intersection isect) {  
    isect.p = r.o;

    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {

        if (length(isect.p - r.o) > 1500.0f) {
          break;
        }

        float closest_distance = scene_SDF(isect);
        
        if (closest_distance < EPSILON_P)
        {
            
            getNormal_SDF(isect);
            isect.t = length(isect.p - r.o);
            isect.distance_to_surface = closest_distance;
            return true;
        }
        
        isect.p = isect.p + r.d * closest_distance;
    }
    
    isect.t = -1.0;
    return false;
}

vec3 shadeIntersection(Intersection isect) {
  vec3 color = vec3(0, 0, 0);

  vec3 material_color = vec3(0,0,0);

    material_color = vec3(0.25, 0.5, 1);
    float t = (isect.p.y / 200.0f);
    t = bias(t, 0.128);
    material_color = mix(material_color, vec3(0.5,0,25), t);


  // sunlight
  float n_dot_light = dot(isect.n, normalize(sun.p - isect.p));
  if (n_dot_light > 0.0f) {
    color += material_color * sun.sunlight.col * n_dot_light;
  }

  // fill light
  n_dot_light = dot(isect.n, fill_light.dir);
  if (n_dot_light > 0.0f) {
    color += material_color * fill_light.col * n_dot_light;
  }

  // gi light
  n_dot_light = dot(isect.n, gi_light.dir);
  if (n_dot_light > 0.0f) {
    color += material_color * gi_light.col * n_dot_light;
  }

  return color;
}


vec3 shadeBackground(Ray r, Intersection isect) {
  vec3 color = vec3(0,0,0);

  float angle = acos(dot(normalize((sun.p - r.o)), r.d)) * 360.0f / PI;

  /*vec3 a = vec3(0.658, 0.208, 0.250);
  vec3 b = vec3(0.538, -1.202, 0.088);
  vec3 c = vec3(-0.147, -0.106, -1.302);
  vec3 d = vec3(0.258, -1.262, -0.152);*/

  vec3 a = vec3(2.768, 0.918, 0.508);
  vec3 b = vec3(0.948, 0.688, -0.762);
  vec3 c = vec3(-0.206, -0.098, -0.269);
  vec3 d = vec3(-0.852, -1.222, -0.672);
  color = getCosinePaletteColor(a, b, c, d, (angle / 180.0f) + abs(r.d.y) * 2.5f) * 0.85;


  a = vec3(1.138, 0.858, 0.768);
  b = vec3(0.051, 0.063, -0.105);
  c = vec3(-0.206, -0.098, -0.269);
  d = vec3(-0.632, -0.482, -0.672);
  vec3 pastelle_palette = getCosinePaletteColor(a, b, c, d, (1.0  - (angle / 180.0f)) - abs(r.d.y)) * 0.9f;

  color = mix(color, pastelle_palette, angle / 170.0);
  //color = pastelle_palette * 0.9f;

  float sun_radius = sun.r_core * 7.5f;
  float corona_radius = (sun.r_corona - sun.r_core) * 4.0f;
  //corona_radius *= tri_wave(angle, 2.0f, 2.0f);

  if (angle < sun_radius) {
    float core_t = 1.0f - (angle / sun_radius);
    color = mix(sun.col_corona, sun.col_core, core_t);
  }
  else {
      if (angle < corona_radius) {
        float corona_t = 1.0 - (angle - sun_radius) / (corona_radius - sun_radius);
        corona_t = bias(corona_t, 0.2725);
        color = mix(color, sun.col_corona, corona_t);

      }
      else {

      }
  }


  return color;
}

Ray genCameraRay(vec2 uv) {
    Ray ray;
    
    float len = tan(PI * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);
    
    ray.o = u_Eye;
    ray.d = dir;
    return ray;
}

void main() {
    vec2 pixel_dimensions = vec2(1.0f / u_Dimensions.x, 1.0f / u_Dimensions.y);

    vec3 color = vec3(0.0f, 0.0f, 0.0f);

    float this_alpha = 0.0f;

    for (int s = 0; s < SPP; ++s) {
      vec2 uv = fs_Pos;

#ifdef MULTISAMPLE
      if (s == 0) {
        uv -= 0.25 * pixel_dimensions;
      }
      else if (s == 1) {
        uv += 0.25 * pixel_dimensions;
      }
      else if (s == 2) {
        uv.x += 0.25 * pixel_dimensions.x;
        uv.y -= 0.25 * pixel_dimensions.y;
      }
      else {
        uv.x -= 0.25 * pixel_dimensions.x;
        uv.y += 0.25 * pixel_dimensions.y;
      }
#endif

      Ray r = genCameraRay(uv);

      Intersection isect;
      isect.uv = uv;
      if (sphereMarch(r, isect)) {
        // render geometry
        color += shadeIntersection(isect);
          float t = exp(-0.0004f * isect.t);
          t = smoothstep(0.0f, 1.0f, t);
        color = mix(shadeBackground(r, isect), color, t);
        this_alpha = 1.0f;
      }

    }

    color /= float(SPP);

    out_Col = vec4(color, this_alpha);
}

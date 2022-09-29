float noise_gen1_1(float x)
{
    return fract(sin(x * 127.1) * 43758.5453);
}
float noise_gen2_1( vec2 p) 
{
    return fract(sin(dot(p.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}
vec2 noise_gen2_2(vec2 p)
{
    return fract(sin(vec2(dot(p, vec2(127.1f, 311.7f)),
                     dot(p, vec2(269.5f,183.3f))))
                     * 43758.5453f);
}
float noise_gen3_1(vec3 p)
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}
float noise_gen4_1(vec4 p)
{
    return fract(sin((dot(p, vec4(127.1, 311.7, 191.999, 433.7)))) * 43758.5453);
}
float interpNoise1D (float noise) {
    float intX = float(floor(noise));
    float fractX = fract(noise);
    float v1 = noise_gen1_1(intX);
    float v2 = noise_gen1_1(intX + 1.0);
    return mix(v1, v2, fractX);
}
float interpNoise2D (vec2 noise) {
    int intX = int(floor(noise.x));
    float fractX = fract(noise.x);
    int intY = int(floor(noise.y));
    float fractY = fract(noise.y);
    float v1 = noise_gen2_1(vec2(intX, intY));
    float v2 = noise_gen2_1(vec2(intX + 1, intY));
    float v3 = noise_gen2_1(vec2(intX, intY + 1));
    float v4 = noise_gen2_1(vec2(intX + 1, intY + 1));
    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}
float interpNoise3D(vec3 noise)
{
    int intX = int(floor(noise.x));
    float fractX = fract(noise.x);
    int intY = int(floor(noise.y));
    float fractY = fract(noise.y);
    int intZ = int(floor(noise.z));
    float fractZ = fract(noise.z);

    float v1 = noise_gen3_1(vec3(intX, intY, intZ));
    float v2 = noise_gen3_1(vec3(intX + 1, intY, intZ));
    float v3 = noise_gen3_1(vec3(intX, intY + 1, intZ));
    float v4 = noise_gen3_1(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise_gen3_1(vec3(intX, intY, intZ + 1));
    float v6 = noise_gen3_1(vec3(intX+1, intY, intZ + 1));
    float v7 = noise_gen3_1(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise_gen3_1(vec3(intX+1, intY+1, intZ + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    float i3 = mix(v5, v6, fractX);
    float i4 = mix(v7, v8, fractX);

    float ii1 = mix(i1, i2, fractY);
    float ii2 = mix(i3, i4, fractY);

    return mix(ii1, ii2, fractZ);
}
float fbm1D(float noise)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.0f;
    float amp = 0.5f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise1D(noise * freq) * amp;
        freq *= 2.0f;
        amp *= persistence;
    }
    return total;
}
float fbm2D(vec2 noise)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.0f;
    float amp = 0.5f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise2D(noise * freq) * amp;
        freq *= 2.0f;
        amp *= persistence;
    }
    return total;
}
float fbm3D(vec3 noise)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.0f;
    float amp = 0.5f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise3D(noise * freq) * amp;
        freq *= 2.0f;
        amp *= persistence;
    }
    return total;
}
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


float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
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

vec3 bendPoint(vec3 p, float k)
{
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    return q;
}
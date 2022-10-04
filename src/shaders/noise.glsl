// so called "canonical" pseudoranom
float random(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float random1d(float x){
    return random(vec2(x, 1.337));
}

float random3d(vec3 inp){
    return random1d(random1d(random1d(inp.x) * inp.y) * inp.z);
}

int inc(int num){
    num++;
    return num;
}

float grad(int hash, float x, float y, float z)
{
    switch(hash & 0xF)
    {
        case 0x0: return  x + y;
        case 0x1: return -x + y;
        case 0x2: return  x - y;
        case 0x3: return -x - y;
        case 0x4: return  x + z;
        case 0x5: return -x + z;
        case 0x6: return  x - z;
        case 0x7: return -x - z;
        case 0x8: return  y + z;
        case 0x9: return -y + z;
        case 0xA: return  y - z;
        case 0xB: return -y - z;
        case 0xC: return  y + x;
        case 0xD: return -y + z;
        case 0xE: return  y - x;
        case 0xF: return -y - z;
        default: return 0.0;
    }
}

float fade(float t) {

    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

int p[512] = int[512](151,160,137,91,90,15,
                      131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
                      190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
                      88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
                      77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
                      102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
                      135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
                      5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
                      223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
                      129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
                      251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
                      49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
                      138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,151,160,137,91,90,15,
                      131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
                      190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
                      88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
                      77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
                      102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
                      135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
                      5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
                      223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
                      129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
                      251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
                      49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
                      138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180);


float lerp(float a, float b, float x) {
    return a + x * (b - a);
}

float lerp2(float a, float b, float x){
    return a*(1.0-x) + b*x;
}


float perlin(float x, float y, float z) {
    //    if(repeat > 0) {
    //        x = x%repeat;
    //        y = y%repeat;
    //        z = z%repeat;
    //    }


    int xi = int(x) & 255;
    int yi = int(y) & 255;
    int zi = int(z) & 255;
    float xf = x-floor(x);
    float yf = y-floor(y);
    float zf = z-floor(z);
    float u = fade(xf);
    float v = fade(yf);
    float w = fade(zf);

    int aaa, aba, aab, abb, baa, bba, bab, bbb;
    aaa = p[p[p[    xi ]+    yi ]+    zi ];
    aba = p[p[p[    xi ]+inc(yi)]+    zi ];
    aab = p[p[p[    xi ]+    yi ]+inc(zi)];
    abb = p[p[p[    xi ]+inc(yi)]+inc(zi)];
    baa = p[p[p[inc(xi)]+    yi ]+    zi ];
    bba = p[p[p[inc(xi)]+inc(yi)]+    zi ];
    bab = p[p[p[inc(xi)]+    yi ]+inc(zi)];
    bbb = p[p[p[inc(xi)]+inc(yi)]+inc(zi)];

    float x1, x2, y1, y2;
    x1 = lerp(    grad (aaa, xf  , yf  , zf),           // The gradient function calculates the dot product between a pseudorandom
                  grad (baa, xf-1.0, yf  , zf),             // gradient vector and the vector from the input coordinate to the 8
                  u);                                     // surrounding points in its unit cube.
    x2 = lerp(    grad (aba, xf  , yf-1.0, zf),           // This is all then lerped together as a sort of weighted average based on the faded (u,v,w)
                  grad (bba, xf-1.0, yf-1.0, zf),             // values we made earlier.
                  u);
    y1 = lerp(x1, x2, v);

    x1 = lerp(    grad (aab, xf  , yf  , zf-1.0),
                  grad (bab, xf-1.0, yf  , zf-1.0),
                  u);
    x2 = lerp(    grad (abb, xf  , yf-1.0, zf-1.0),
                  grad (bbb, xf-1.0, yf-1.0, zf-1.0),
                  u);
    y2 = lerp (x1, x2, v);

    return (lerp (y1, y2, w)+1.0)/2.0;                      // For convenience we bind the result to 0 - 1 (theoretical min/max before is [-1, 1])
}




float bilinear_interp(float a, float b, float c, float d, float x, float y){

    float left = lerp(a, b, x);
    float right = lerp(c, d, x);
    return lerp(left, right, y);
}

float trilinear_interp(float a, float b, float c, float d, float e, float f, float g, float h, float x, float y, float z){
    float bottom = bilinear_interp(a, b, c, d, x, y);
    float top = bilinear_interp(e, f, g, h, x, y);
    return lerp(bottom, top, z);
}

float cos_interp1(float a, float b, float x){
    float cos_t = (1.0 - cos(x*3.41459)) * 0.5;
    return lerp(a, b, cos_t);
}

float trilinear_interp2(float a, float b, float c, float d, float e, float f, float g, float h, float x, float y, float z){
    // adapted from https://en.wikipedia.org/wiki/Trilinear_interpolation

    float xd = (x - floor(x));
    float yd = (y - floor(y));
    float zd = (z - floor(z));

    float c00 = cos_interp1(a, d, xd);
    float c01 = cos_interp1(b, c, xd);
    float c10 = cos_interp1(e, h, xd);
    float c11 = cos_interp1(f, g, xd);

    float c0 = cos_interp1(c00, c10, yd);
    float c1 = cos_interp1(c01, c11, yd);

    float cf = cos_interp1(c0, c1, zd);

    return cf;
}

// so called "canonical" pseudoranom
float random_1(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float random1d_1(float x){
    return random_1(vec2(x, 1.337));
}

float random3d_1(vec3 inp){
    return random1d_1(random1d_1(random1d_1(inp.x) * inp.y) * inp.z);
}

// trilinear
// const float lattice_spacing = 0.1;

// lattice point before
float l_b(float d, float ls){
    return floor(d / ls) * ls;
}

// lattice point after
float l_a(float d, float ls){
    return ceil(d / ls) * ls;
}

float interp_noise(float x, float y, float z, float ls){
    // interpolating the surrounding lattice values (for 3D, this means the surrounding eight 'corner' points)

    // start by assigning lattice as whole numbers to start
    float a = random3d_1(vec3(l_b(x, ls), l_b(y, ls), l_b(z, ls)));
    float b = random3d_1(vec3(l_b(x, ls), l_a(y, ls), l_b(z, ls)));
    float c = random3d_1(vec3(l_a(x, ls), l_a(y, ls), l_b(z, ls)));
    float d = random3d_1(vec3(l_a(x, ls), l_a(y, ls), l_b(z, ls)));
    float e = random3d_1(vec3(l_b(x, ls), l_b(y, ls), l_a(z, ls)));
    float f = random3d_1(vec3(l_b(x, ls), l_a(y, ls), l_a(z, ls)));
    float g = random3d_1(vec3(l_a(x, ls), l_a(y, ls), l_a(z, ls)));
    float h = random3d_1(vec3(l_a(x, ls), l_b(y, ls), l_a(z, ls)));

    return trilinear_interp2(a, b, c, d, e, f, g, h, x, y, z);
}

const float N_OCTAVES = 2.0;
const float PERSISTANCE = 1.0 / 2.0;
const float lattice_spacing_mod = 0.002;
const float shift_freq = 100.0;

float fbm3d(float x, float y, float z){
    float total = 0.0;
    for (float i = 0.0; i < N_OCTAVES; ++i){
        float frequency = pow(2.0, i);
        //float power = pow(2.0, i);
        float amplitude = pow(PERSISTANCE, i);

        total += amplitude * interp_noise(x, y, z, (1.0/(frequency * 1000.0)) * lattice_spacing_mod);
    }
    return total / 1.0;
}

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise_ref(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}


float fbm3d_2(vec3 x) {
    float v = 0.0;

    vec3 shift = vec3(shift_freq);
    for (float i = 0.0; i < N_OCTAVES; ++i) {
        float amplitude = pow(PERSISTANCE, i);
        v += amplitude * noise_ref(x);
        x = x * 2.0 + shift;

    }
    return v;
}
#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform sampler2D u_Texture;

in vec4 fs_Pos;
out vec4 out_Col;

#define RGB vec3
#define mul(a,b) b*a
#define saturate(a) clamp( a, 0.0, 1.0 )

// COLOR SCHEME
const float _FogMul = -0.00800 ;
const float _FogPow = 1.00000 ;
const vec3 _LightDir = vec3(-0.33047, 0.77328, -0.42927) ;
const vec3 _SunStar = vec3(7.7, 6.17, 0.1) ;
const float _SunSize = 26.00000 ;
const float _SunScale = 15.00000 ;
const float _ExposureOffset = 11.10000 ;
const float _ExposurePower = 0.52000 ;
const float _ExposureStrength = 0.09000 ;
const RGB _SunColor = RGB(1, 0.95441, 0.77206) ;
const RGB _Zenith = RGB(0.77941, 0.5898, 0.41263) ;
const float _ZenithFallOff = 2.36000 ;
const RGB _Nadir = RGB(1, 0.93103, 0) ;
const float _NadirFallOff = 1.91000 ;
const RGB _Horizon = RGB(0.96324, 0.80163, 0.38954) ;
const RGB _CharacterMainColor = RGB(0.60294, 0.1515, 0.062067) ;
const RGB _CharacterTerrainCol = RGB(0.35294, 0.16016, 0.12197) ;
const RGB _CharacterCloakDarkColor = RGB(0.25735, 0.028557, 0.0056769) ;
const RGB _CharacterYellowColor = RGB(0.88971, 0.34975, 0) ;
const RGB _CharacterWhiteColor = RGB(0.9928, 1, 0.47794) ;
const float _CharacterBloomScale = 0.70000 ;
const float _CharacterDiffScale = 1.50000 ;
const float _CharacterFreScale = 1.77000 ;
const float _CharacterFrePower = 3.84000 ;
const float _CharacterFogScale = 4.55000 ;
const float _CloudTransparencyMul = 0.90000 ;
const RGB _CloudCol = RGB(1, 0.84926, 0.69853) ;
const RGB _BackCloudCol = RGB(0.66176, 0.64807, 0.62284) ;
const RGB _CloudSpecCol = RGB(0.17647, 0.062284, 0.062284) ;
const RGB _BackCloudSpecCol = RGB(0.11029, 0.05193, 0.020275) ;
const float _CloudFogStrength = 0.50000 ;
const RGB _TombMainColor = RGB(0.64706, 0.38039, 0.27451) ;
const RGB _TombScarfColor = RGB(0.38971, 0.10029, 0.10029) ;
const RGB _PyramidCol = RGB(0.69853, 0.40389, 0.22086) ;
const vec2 _PyramidHeightFog = vec2(38.66, 1.3) ;
const RGB _TerrainCol = RGB(0.56618, 0.29249, 0.1915) ;
const RGB _TerrainSpecColor = RGB(1, 0.77637, 0.53676) ;
const float _TerrainSpecPower = 55.35000 ;
const float _TerrainSpecStrength = 1.56000 ;
const float _TerrainGlitterRep = 7.00000 ;
const float _TerrainGlitterPower = 3.20000 ;
const RGB _TerrainRimColor = RGB(0.16176, 0.13131, 0.098724) ;
const float _TerrainRimPower = 5.59000 ;
const float _TerrainRimStrength = 1.61000 ;
const float _TerrainRimSpecPower = 2.88000 ;
const float _TerrainFogPower = 2.11000 ;
const vec4 _TerrainShadowParams = vec4(0.12, 5.2, 88.7, 0.28) ;
const vec3 _TerrainAOParams = vec3(0.01, 0.02, 2) ;
const RGB _TerrainShadowColor = RGB(0.48529, 0.13282, 0) ;
const RGB _TerrainDistanceShadowColor = RGB(0.70588, 0.4644, 0.36851) ;
const float _TerrainDistanceShadowPower = 0.11000 ;
const RGB _FlyingHelperMainColor = RGB(0.85294, 0.11759, 0.012543) ;
const RGB _FlyingHelperCloakDarkColor = RGB(1, 0.090909, 0) ;
const RGB _FlyingHelperYellowColor = RGB(1, 0.3931, 0) ;
const RGB _FlyingHelperWhiteColor = RGB(1, 1, 1) ;
const float _FlyingHelperBloomScale = 2.61000 ;
const float _FlyingHelperFrePower = 1.00000 ;
const float _FlyingHelperFreScale = 0.85000 ;
const float _FlyingHelperFogScale = 1.75000 ;
// ============================================================

//==========================================================================================
// Play with these at your own risk. Expect, unexpected results!
//==========================================================================================

const mat4 _CameraInvViewMatrix = mat4( 1, 0, 0, 1.04, 
0, 0.9684963, 0.2490279, 2.2, 
0, 0.2490279, -0.9684963, 18.6, 
0, 0, 0, 1 ) ;
const vec3 _CameraFOV = vec3(1.038, 0.78984, -1) ;
const vec3 _CameraPos = vec3(1.0, 2.2, 18.6) ;
const vec4 _CameraMovement = vec4(0.15, 0.1, 0.2, 0.25) ;

const vec3 _WindDirection = vec3(-0.27, -0.12, 0) ;

const float _DrawDistance = 70.00000 ;
const float _MaxSteps = 64.00000 ;

const float _TempleRotation = 0.17000 ;
const vec3 _TemplePosition = vec3(0.52, 2.35, 17.6) ;
const vec3 _TempleScale = vec3(0.4, 0.53, 0.38) ;


const vec3 _SunPosition = vec3(-30.3, 60, -40.1) ;
const float _CharacterRotation = 0.17000 ;
const vec3 _CharacterPosition = vec3(0.52, 2.35, 17.6) ;
const vec3 _CharacterScale = vec3(0.4, 0.53, 0.38) ;
const float _MainClothRotation = 0.30000 ;
const vec3 _MainClothScale = vec3(0.3, 0.68, 0.31) ;
const vec3 _MainClothPosition = vec3(0, -0.12, 0) ;
const vec3 _MainClothBotCutPos = vec3(0, -0.52, 0) ;
const vec3 _MainClothDetail = vec3(6, 0.04, 1.3) ;
const float _HeadScarfRotation = -0.19000 ;
const vec3 _HeadScarfPosition = vec3(-0.005, -0.16, -0.01) ;
const vec3 _HeadScarfScale = vec3(0.18, 0.2, 0.03) ;
const float _HeadRotationX = -0.30000 ;
const float _HeadRotationY = 0.29000 ;
const float _HeadRotationZ = 0.00000 ;
const vec3 _HeadPos = vec3(0, -0.04, 0.01) ;
const vec3 _LongScarfPos = vec3(0.01, -0.15, 0.09) ;
const vec3 _LongScarfScale = vec3(0.05, 1.25, 0.001) ;
const vec4 _LongScarfWindStrength = vec4(0.3, 4.52, 5.2, 0.02) ;
const float _LongScarfRotX = 1.43000 ;
const float _LongScarfMaxRad = 1.99000 ;
const vec3 _FacePosition = vec3(0, -0.01, 0.05) ;
const vec3 _FaceSize = vec3(0.038, 0.05, 0.03) ;
const vec3 _UpperLeftLegA = vec3(-0.02, -0.37, 0.01) ;
const vec3 _UpperLeftLegB = vec3(-0.02, -0.67, -0.059999) ;
const vec3 _UpperLeftLegParams = vec3(0.026, 1, 1) ;
const vec3 _LowerLeftLegA = vec3(-0.02, -0.67, -0.059999) ;
const vec3 _LowerLeftLegB = vec3(-0.02, -0.77, 0.12) ;
const vec3 _LowerLeftLegParams = vec3(0.028, 0.03, 0.01) ;
const vec3 _UpperRightLegA = vec3(0.07, -0.5, 0.02) ;
const vec3 _UpperRightLegB = vec3(0.07, -0.61, 0.09) ;
const vec3 _UpperRightLegParams = vec3(0.026, 1, 1) ;
const vec3 _LowerRightLegA = vec3(0.07, -0.61, 0.09) ;
const vec3 _LowerRightLegB = vec3(0.07, -0.91, 0.22) ;
const vec3 _LowerRightLegParams = vec3(0.028, 0.03, 0.01) ;
const vec3 _BodyPos = vec3(0, -0.45, -0.03) ;
const vec3 _CharacterTrailOffset = vec3(0.72, 0.01, 0.06) ;
const vec3 _CharacterTrailScale = vec3(0.001, 0, 0.5) ;
const vec3 _CharacterTrailWave = vec3(1.97, 0, 0.34) ;
const vec2 _CharacterHeightTerrainMix = vec2(1.95, -30) ;
const vec3 _CloudNoiseStrength = vec3(0.2, 0.16, 0.1) ;
const vec3 _FrontCloudsPos = vec3(9.91, 8.6, -15.00) ;
const vec3 _FrontCloudsOffsetA = vec3(-9.1, 3.04, 0) ;
const vec3 _FrontCloudsOffsetB = vec3(-2.97, 3.72, -0.05) ;
const vec3 _FrontCloudParams = vec3(5.02, 3.79, 5) ;
const vec3 _FrontCloudParamsA = vec3(3.04, 0.16, 2) ;
const vec3 _FrontCloudParamsB = vec3(1.34, 0.3, 3.15) ;
const vec3 _BackCloudsPos = vec3(29.99, 13.61, -20.8) ;
const vec3 _BackCloudsOffsetA = vec3(24.87, -1.49, 0) ;
const vec3 _BackCloudParams = vec3(7.12, 4.26, 1.68) ;
const vec3 _BackCloudParamsA = vec3(6.37, 2.23, 2.07) ;
const vec3 _PlaneParams = vec3(7.64, 10.85, 3.76) ;
const vec3 _CloudGlobalParams = vec3(0.123, 2.1, 0.5) ;
const vec3 _CloudBackGlobalParams = vec3(0.16, 1.4, -0.01) ;
const vec3 _CloudNormalMod = vec3(0.26, -0.13, 1.22) ;
const float _CloudSpecPower = 24.04000 ;
const float _CloudPyramidDistance = 0.14500 ;
const vec3 _TombPosition = vec3(5, 5, 9.28) ;
const vec3 _TombScale = vec3(0.07, 0.5, 0.006) ;
const vec3 _TombBevelParams = vec3(0.44, 0.66, 0.01) ;
const float _TombRepScale = 0.79000 ;
const vec3 _TombCutOutScale = vec3(0.39, 0.06, -14.92) ;
const vec3 _TombScarfOffset = vec3(0, 0.46, 0) ;
const vec3 _TombScarfWindParams = vec3(-1.61, 6, 0.05) ;
const vec3 _TombScarfScale = vec3(0.03, 0.002, 0.5) ;
const float _TombScarfRot = -0.88000 ;
const mat4 _TombScarfMat = mat4( 0.9362437, 0, -0.3513514, 0, 
0, 1, 0, 0, 
0.3513514, 0, 0.9362437, 0, 
0, 0, 0, 1 ) ;
const vec3 _PyramidPos = vec3(-18.0, 10.9, -50) ;
const vec3 _PyramidScale = vec3(41.1, 24.9, 18) ;
const vec3 _PrismScale = vec3(1, 1.9, 1) ;
const vec3 _PyramidNoisePrams = vec3(1.5, 1, 1) ;
const vec3 _PrismEyeScale = vec3(0.7, 1.9, 51.5) ;
const vec3 _PyramidEyeOffset = vec3(2.0, -4.9, 0) ;
const float _PrismEyeWidth = 5.86000 ;
const float _TerrainMaxDistance = 28.04000 ;
const float _SmallDetailStrength = 0.00600 ;
const vec3 _SmallWaveDetail = vec3(3.19, 16, 6.05) ;
const vec2 _WindSpeed = vec2(2, 0.6) ;
const float _MediumDetailStrength = 0.05000 ;
const vec2 _MediumWaveDetail = vec2(2, 50) ;
const vec3 _MediumWaveOffset = vec3(0.3, -2, 0.1) ;
const vec2 _LargeWaveDetail = vec2(0.25, 0.73) ;
const vec3 _LargeWavePowStre = vec3(0.6, 2.96, -2.08) ;
const vec3 _LargeWaveOffset = vec3(-3.9, 4.41, -11.64) ;
const vec3 _FlyingHelperPos = vec3(2.15, 4.68, 14.4) ;
const vec3 _FlyingHelperScale = vec3(0.25, 0.001, 0.3) ;
const vec3 _FlyingHelperMovement = vec3(0.44, 1.44, -2.98) ;
const vec3 _FlyingHelperScarfScale = vec3(0.1, 0.001, 1.5) ;
const vec3 _FlyingHelperScarfWindParams = vec3(-0.06, 0.31, 0.47) ;
const vec3 _FlyingHelperScarfWindDetailParams = vec3(3.93, 0.005, -45.32) ;
const vec3 _FlyingHelperSideScarfOffset = vec3(0.16, -0.01, 0) ;
const vec3 _FlyingHelperSideScarfScale = vec3(0.06, 0.001, 0.8) ;
const vec4 _FlyingScarfSideWindParams = vec4(2.46, -1.59, -0.05, 0.21) ;

// Material ID definitions
#define MAT_PYRAMID 1.0

#define MAT_TERRAIN 10.0
#define MAT_TERRAIN_TRAIL 11.0

#define MAT_BACK_CLOUDS 20.0
#define MAT_FRONT_CLOUDS 21.0

#define MAT_TOMB 30.0
#define MAT_TOMB_SCARF 31.0

#define MAT_FLYING_HELPERS 40.0
#define MAT_FLYING_HELPER_SCARF 41.0

#define MAT_CHARACTER_BASE 50.0
#define MAT_CHARACTER_MAIN_CLOAK 51.0
#define MAT_CHARACTER_HAIR 52.0
#define MAT_CHARACTER_DRESS 53.0

#define TEST_MAT_LESS( a, b ) a < (b + 0.1)
#define TEST_MAT_GREATER( a, b ) a > (b - 0.1)

//==========================================================================================
// Primitive functions by IQ
//==========================================================================================
float sdRoundBox(vec3 p, vec3 b, float r)
{
	return length( max( abs(p) - b, 0.0) ) - r;
}

float sdSphere(vec3 p, float s)
{
	return length(p) - s;
}

float sdPlane( vec3 p )
{
	return p.y;
}

float sdBox(vec3 p, vec3 b)
{
	vec3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

float sdCylinder(vec3 p, vec2 h)
{
	vec2 d = abs(vec2(length(p.xz), p.y)) - h;
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCone( in vec3 p, in vec2 c, float h )
{
  // c is the sin/cos of the angle, h is height
  // Alternatively pass q instead of (c,h),
  // which is the point at the base in 2D
  vec2 q = h*vec2(c.x/c.y,-1.0);
    
  vec2 w = vec2( length(p.xz), p.y );
  vec2 a = w - q*clamp( dot(w,q)/dot(q,q), 0.0, 1.0 );
  vec2 b = w - q*vec2( clamp( w.x/q.x, 0.0, 1.0 ), 1.0 );
  float k = sign( q.y );
  float d = min(dot( a, a ),dot(b, b));
  float s = max( k*(w.x*q.y-w.y*q.x),k*(w.y-q.y)  );
  return sqrt(d)*sign(s);
}

float sdCapsule( vec3 pos, vec3 a, vec3 b, float r )
{
  vec3 pa = pos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float sdVerticalCapsule( vec3 p, float h, float r )
{
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}

float sdPlane(vec3 p, vec4 n)
{
	// n must be normalized
	return dot(p, n.xyz) + n.w;
}

vec2 sdSegment( in vec3 p, vec3 a, vec3 b )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return vec2( length( pa - ba*h ), h );
}

float sdEllipsoid(in vec3 p, in vec3 r)
{
	return (length(p / r) - 1.0) * min(min(r.x, r.y), r.z);
}

float sdTriPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
#if 0
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
#else
    float d1 = q.z-h.y;
    float d2 = max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5;
    return length(max(vec2(d1,d2),0.0)) + min(max(d1,d2), 0.);
#endif
}

//==========================================================================================
// Smooth Function
//==========================================================================================

float smoothUnion( float d1, float d2, float k ) {
  float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
  return mix( d2, d1, h ) - k*h*(1.0-h); 
}


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

//==========================================================================================
// distance field operations
//==========================================================================================
vec2 min_mat( vec2 d1, vec2 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

vec2 smin_mat( vec2 a, vec2 b, float k, float c )
{
    float h = clamp( 0.5+0.5*(b.x-a.x)/k, 0.0, 1.0 );
    float x = mix( b.x, a.x, h ) - k*h*(1.0-h);
    return vec2( x, ( h < c ) ? b.y : a.y);
}

float smax( float a, float b, float k )
{
	float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
	return mix( a, b, h ) + k*h*(1.0-h);
}

//==========================================================================================
// Rotations
//==========================================================================================
void rX(inout vec3 p, float a) {
    vec3 q = p;
    float c = cos(a);
    float s = sin(a);
    p.y = c * q.y - s * q.z;
    p.z = s * q.y + c * q.z;
}

void rY(inout vec3 p, float a) {
    vec3 q = p;
    float c = cos(a);
    float s = sin(a);
    p.x = c * q.x + s * q.z;
    p.z = -s * q.x + c * q.z;
}

void rZ(inout vec3 p, float a) {
    vec3 q = p;
    float c = cos(a);
    float s = sin(a);
    p.x = c * q.x + s * q.y;
    p.y = -s * q.x + c * q.y;
}

//==========================================================================================
// Value noise and its derivatives: https://www.shadertoy.com/view/MdX3Rr
//==========================================================================================
vec3 noised( in vec2 x )
{
    vec2 f = fract(x);
    vec2 u = f*f*(3.0-2.0*f);

#if 0
  // texel fetch version
  ivec2 p = ivec2(floor(x));
  float a = texelFetch( u_Texture, (p+ivec2(0,0))&255, 0 ).x;
	float b = texelFetch( u_Texture, (p+ivec2(1,0))&255, 0 ).x;
	float c = texelFetch( u_Texture, (p+ivec2(0,1))&255, 0 ).x;
	float d = texelFetch( u_Texture, (p+ivec2(1,1))&255, 0 ).x;
#else    
  // texture version    
  vec2 p = floor(x);
	float a = textureLod( u_Texture, (p+vec2(0.5,0.5))/256.0, 0.0 ).x;
	float b = textureLod( u_Texture, (p+vec2(1.5,0.5))/256.0, 0.0 ).x;
	float c = textureLod( u_Texture, (p+vec2(0.5,1.5))/256.0, 0.0 ).x;
	float d = textureLod( u_Texture, (p+vec2(1.5,1.5))/256.0, 0.0 ).x;
#endif
    
	return vec3(a+(b-a)*u.x+(c-a)*u.y+(a-b-c+d)*u.x*u.y,
				6.0*f*(1.0-f)*(vec2(b-a,c-a)+(a-b-c+d)*u.yx));
}

//==========================================================================================
// Noise function: https://www.shadertoy.com/view/4sfGRH 
//==========================================================================================
float pn(vec3 p) {
    vec3 i = floor(p); 
	vec4 a = dot(i, vec3(1., 57., 21.)) + vec4(0., 57., 21., 78.);
    vec3 f = cos((p-i)*3.141592653589793)*(-.5) + .5;  
	a = mix(sin(cos(a)*a), sin(cos(1.+a)*(1.+a)), f.x);
    a.xy = mix(a.xz, a.yw, f.y);   
	return mix(a.x, a.y, f.z);
}

//==========================================================================================
// Sin Wave approximation http://http.developer.nvidia.com/GPUGems3/gpugems3_ch16.html
//==========================================================================================
vec4  SmoothCurve( vec4 x ) {  
  return x * x * ( 3.0 - 2.0 * x );  
}

vec4 TriangleWave( vec4 x ) {  
  return abs( fract( x + 0.5 ) * 2.0 - 1.0 );  
}

vec4 SmoothTriangleWave( vec4 x ) {  
  return SmoothCurve( TriangleWave( x ) );  
}  

float SmoothTriangleWave( float x )
{
  return SmoothCurve( TriangleWave( vec4(x,x,x,x) ) ).x;  
}  

void Bend(inout vec3 vPos, vec2 vWind, float fBendScale)
{
	float fLength = length(vPos);
	float fBF = vPos.y * fBendScale;  
	fBF += 1.0;  
	fBF *= fBF;  
	fBF = fBF * fBF - fBF;  
	vec3 vNewPos = vPos;  
	vNewPos.xz += vWind.xy * fBF;  
	vPos.xyz = normalize(vNewPos.xyz)* fLength;  
}

//==========================================================================================
// The big mountain in the distance. Again, not a pyramid
//==========================================================================================
float sdBigMountain( in vec3 pos )
{
    float scaleMul = min(_PyramidScale.x, min(_PyramidScale.y, _PyramidScale.z));
    vec3 posPyramid	= pos - _PyramidPos;

    // Apply noise derivative, then we can use a blocky looking texture to make the mountain
    // look edgy (for lack of better word)
    float derNoise		= sin(noised(posPyramid.xz * _PyramidNoisePrams.x).x) * _PyramidNoisePrams.y;
    posPyramid.x		= posPyramid.x + derNoise;

    posPyramid /= _PyramidScale;
    float pyramid = sdTriPrism(  posPyramid, _PrismScale.xy ) * scaleMul;

    // The piercing eye. Which is just an inverted pyrmaid on top of main pyramid.
    float eyeScale = _PyramidScale.x;

    vec3 posEye = pos;
    posEye.y = _PrismEyeScale.z - pos.y;
    posEye.x = pos.x * _PrismEyeWidth;

	float eye = sdTriPrism(  (posEye -_PyramidEyeOffset) / eyeScale, _PrismEyeScale.xy ) * eyeScale;
	return max(pyramid, -eye);
}

//==========================================================================================
// Main desert shape
//==========================================================================================
float sdLargeWaves( in vec3 pos )
{
	// The main shape of terrain. Just sin waves, along X and Z axis, with a power
	// curve to make the shape more pointy 

  // Manipulate the height as we go in the distance
  // We want terrain to be a specific way closer to character, showing a path, but the path 
  // gets muddier as wo go in the distance.

  float distZ = abs(pos.z - _CameraPos.z);
  float distX = abs(pos.x - _CameraPos.x);
  float dist = (distZ ) + (distX * 0.1);
  dist = dist * dist * 0.01;

  float detailNoise = noised(pos.xz).x * -2.5; 
	float largeWaves = (sin(_LargeWaveOffset.z + pos.z * _LargeWaveDetail.y + pos.z * 0.02)  
					  * sin((_LargeWaveOffset.x + dist) + (pos.x * _LargeWaveDetail.x) ) * 0.5) + 0.5;
  largeWaves = -_LargeWaveOffset.y + pow( largeWaves, _LargeWavePowStre.x) *  _LargeWavePowStre.y - detailNoise * 0.1 ;// - (-pos.z*_LargeWavePowStre.z);// 

  // Smoothly merge with the bottom plane of terrain
  largeWaves = smin(largeWaves, _LargeWavePowStre.z, 0.2);
  largeWaves = (largeWaves - dist);
  return largeWaves * 0.9;
}

float sdSmallWaves( in vec3 pos )
{
  // movement to give feel of wind blowing
  float detailNoise = noised(pos.xz).x * _SmallWaveDetail.z; 
	float smallWaves = sin(pos.z * _SmallWaveDetail.y + detailNoise + u_Time * 0.01 * _WindSpeed.y ) * 
					   sin(pos.x * _SmallWaveDetail.x + detailNoise + u_Time * 0.01 * _WindSpeed.x ) * _SmallDetailStrength;
	
	return smallWaves * 0.9;
}

float sdTerrain( in vec3 pos)
{
	float smallWaves = sdSmallWaves( pos );
	float largeWaves = sdLargeWaves( pos );

  return (smallWaves + largeWaves);
}

vec2 sdDesert( in vec3 pos, in float terrain )
{
    float distanceToPos = length(pos.xz - _CameraPos.xz);
    if( distanceToPos > _TerrainMaxDistance)
        return vec2(_DrawDistance, 0.0);	

   	float mat = 9.0;//length(pos.xyz) > 9.0 ? 10.0 : 40.0;
    return vec2( pos.y + terrain, MAT_TERRAIN );
}

//==========================================================================================
// Character
//==========================================================================================
float sdCharacter(vec3 pos)
{
  pos -= vec3(-0.1, -0.4, -0.5);
  float res = 10000000.0;
  float head = sdSphere(pos + vec3(0.0, -0.05, 0.0), 0.1);
  res = min(res, head);
  float hairL = sdSphere(pos + vec3(-0.11, -0.1, -0.05), 0.06);
  res = min(res, hairL);
  float hairR = sdSphere(pos + vec3(0.11, -0.1, -0.05), 0.06);
  res = min(res, hairR);

  float cloak = sdCone(pos, vec2(0.9, 0.5), 0.2);
  
  res = smoothUnion(res, cloak, 0.01);

  float body = sdCylinder(pos + vec3(0.0, 0.2, 0.0), vec2(0.15, 0.1));
  res = min(res, body);

  float leftLeg = sdVerticalCapsule(pos + vec3(-0.08, 0.4, 0.0), 0.1, 0.03);
    float rightLeg = sdVerticalCapsule(pos + vec3(0.08, 0.4, 0.0), 0.1, 0.03);
  float dt2 = min(leftLeg, rightLeg);

  res = min(res,dt2);
  return res;
}

vec2 sdCharacter1(vec3 pos)
{
  pos -= _TemplePosition;
  vec3 scale = _TempleScale;
  float scaleMul = min(scale.x, min(scale.y, scale.z));

  rY(pos, - _TempleRotation);
  pos /= scale;
  pos -= vec3(4.1, 0.0, -1.5);

  float head = sdSphere(pos + vec3(0.0, -0.05, 0.0), 0.1);
  vec2 headMat = vec2(head, MAT_CHARACTER_BASE);

  float hair;

  float hairR1 = sdSphere(pos + vec3(-0.11, -0.02, -0.05), 0.05);
  float hairL1 = sdSphere(pos + vec3(0.11, -0.02, -0.05), 0.05);
  hair = min(hairL1, hairR1);

  float hairR2 = sdSphere(pos + vec3(-0.15, 0.03, -0.08), 0.04);
  float hairL2 = sdSphere(pos + vec3(0.18, 0.03, -0.08), 0.04);
  hair = min(hair, min(hairL2, hairR2));

  float hairR3 = sdSphere(pos + vec3(-0.18, 0.07, -0.12), 0.03);
  float hairL3 = sdSphere(pos + vec3(0.24, 0.07, -0.12), 0.03);
  hair = min(hair, min(hairL3, hairR3));

  float hairMainT = sdSphere(pos + vec3(0.0, -0.05, 0.0), 0.12);
  float hairMainB = sdBox(pos + vec3(0.0, 0.2, 0.0), vec3(0.2, 0.2, 0.2));
  float hairM = smoothSubtraction(hairMainB, hairMainT, 0.01);

  hair = min(hair, hairM);
  vec2 hairMat = vec2(hair, MAT_CHARACTER_HAIR);
  hairMat = min_mat(headMat, hairMat);

  float cloak = sdCone(pos, vec2(0.9, 0.5), 0.2);
  //clock = smoothUnion(head, cloak, 0.01);
  vec2 clockMat = vec2(cloak, MAT_CHARACTER_MAIN_CLOAK);
  clockMat = min_mat(hairMat, clockMat);

  float body = sdCylinder(pos + vec3(0.0, 0.2, 0.0), vec2(0.15, 0.1));
  vec2 bodyMat = vec2(body, MAT_CHARACTER_DRESS);
  bodyMat = min_mat(clockMat, bodyMat);

  float leftLeg = sdVerticalCapsule(pos + vec3(-0.08, 0.4, 0.0), 0.1, 0.03);
  float rightLeg = sdVerticalCapsule(pos + vec3(0.08, 0.4, 0.0), 0.1, 0.03);
  float legs = min(leftLeg, rightLeg);
  vec2 legsMat = vec2(legs, MAT_CHARACTER_BASE);
  
  vec2 characterMat = min_mat(legsMat, bodyMat);
  characterMat.x *= scaleMul;

  return characterMat;
}

//==========================================================================================
// Building
//==========================================================================================

float sdFrontTemple(vec3 pos)
{
    vec3 basePos = pos - vec3(-1.0, -0.4, -1.0);
    float res = 10000000.0;
    const int TEMPLE_NUM = 2;
    vec3 horiOffset = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < TEMPLE_NUM; i++) {
      float leftMain   = sdBox(basePos + horiOffset, vec3(0.2, 0.5, 0.2)); 
      res = min(res, leftMain);

      vec3 vertBasePosLeft = basePos + horiOffset - vec3(0.0, 0.5, 0.0);
      float baseWidth = 0.2;
      float baseLength = 0.3;
      float baseHeight = 0.06;
      float lengthInc = 0.2;
      vec3 vertOffset = vec3(0.0, 0.0, 0.0);
      for (int j = 0; j < 3; j++) {
        float stone  = sdBox(vertBasePosLeft + vertOffset, vec3(baseLength + lengthInc, baseHeight, baseWidth)); 
        res = min(res, stone);
        vertOffset = vertOffset - vec3(0.0, baseHeight * 2.0, 0.0);
        lengthInc += 0.2;
      }
      horiOffset = horiOffset - vec3(1.8, 0.0, 0.0);
    }
    return res;
}

float sdMidTemple(vec3 pos, float neckLens)
{
    vec3 basePos = pos - vec3(-4.0, -0.8, -2.0);
    float res = 10000000.0;
    const int TEMPLE_NUM = 1;
    vec3 scale = _TempleScale;

    float bottom1   = sdBox(basePos, vec3(0.4, 2.0, 0.4)); 
    res = min(res, bottom1);
    float neck   = sdCylinder(basePos - vec3(0.0, 2.0, 0.0), vec2(0.4, neckLens)); 
    res = min(res, neck);
    float bottom2   = sdBox(basePos - vec3(0.0, 2.0 + neckLens + 0.05, 0.0), vec3(0.4, 0.3, 0.4)); 
    res = min(res, bottom2);
	float bottom3   = sdCylinder(basePos - vec3(0.0, 2.0 + neckLens + 0.15, 0.0), vec2(0.6, 0.1));
    res = smoothUnion(res, bottom3, 0.1);

    return res;
}


float sdMushroom(vec3 pos) 
{
    //pos -= vec3 (-3.0, -0.5, -1.3);
    vec3 basePos = pos;
    float mushroomT = sdSphere(basePos - vec3(0.0, 0.1, 0.0), 0.5);
    float mushroomB = sdBox(basePos, vec3(0.6, 0.4, 0.6));
    float dt1 = smoothSubtraction(mushroomB, mushroomT, 0.0);
    
    float root = sdCapsule(basePos - vec3(0.0, -0.4, 0.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 0.6, 0.0), 0.1);
    
    float dt2 = smoothUnion(root, dt1, 0.3);
    return dt2;
}

float sdMushrooms(vec3 pos) 
{
    const int MUSHROOM_NUM = 3;
    vec3 basePos = pos - vec3(0.0, -0.2, 0.0);
    float res = 10000.0;
    vec3 vertOffset = vec3(0.55, 0.0, 0.0);
    for (int i = 0; i < MUSHROOM_NUM; i++) {
      float mushroom = sdMushroom(basePos);
      res = min(res, mushroom);
      basePos -= vertOffset;
    }

    // the right-most mushroom
    basePos -= vec3(0.2, 0.2, 0.0);
    float mushroomT = sdSphere(basePos - vec3(0.0, 0.3, 0.0), 0.5);
    float mushroomB = sdBox(basePos, vec3(0.6, 0.6, 0.6));
    float dt1 = smoothSubtraction(mushroomB, mushroomT, 0.0);
    float root = sdCapsule(basePos - vec3(0.0, -0.4, 0.0), vec3(0.0, -0.3, 0.0), vec3(0.0, 0.8, 0.0), 0.1);
    float dt2 = smoothUnion(root, dt1, 0.3);
    res = min(res, dt2);

    // the store on top
    float stem1 = sdCylinder(basePos - vec3(0.65, -0.3, 0.0), vec2(0.12, 0.5));
    res = min(res, stem1);

    float stem2 = sdCylinder(basePos - vec3(1.25, -0.5, 0.0), vec2(0.2, 0.3));
    res = min(res, stem2);

    return res;
}

float sdBackRightTemple(vec3 pos)
{
    vec3 basePos = pos - vec3(-1.0, -0.8, -1.0);
    float res = 10000000.0;
    const int TEMPLE_NUM = 1;
    vec3 scale = _TempleScale;

    float bottom1   = sdBox(basePos, vec3(0.4, 1.5, 0.4)); 
    res = min(res, bottom1);
    float neck   = sdCylinder(basePos - vec3(0.0, 1.5, 0.0), vec2(0.4, 0.4)); 
    res = min(res, neck);
    float bottom2   = sdBox(basePos - vec3(0.0, 1.95, 0.0), vec3(0.4, 0.3, 0.4)); 
    res = min(res, bottom2);

    pos *= scale;
    rY(pos, _TempleRotation * 3.2);
    pos /= scale;
    basePos = pos - vec3(-1.0, -0.8, -1.0);

    float top1  = sdBox(basePos - vec3(2.0, 2.6, 0.0), vec3(3, 0.2, 0.4)); 
    basePos *= scale;
    rZ(basePos, -_TempleRotation * 3.0);
    basePos /= scale;
    // create a "cut" on the top
    float top2  = sdBox(basePos - vec3(-0.3, 2.6, 0.0), vec3(0.4, 0.1, 0.4)); 
    float top = smoothSubtraction(top2, top1, 0.05);
    res = min(res, top);
    
    float mushroom = sdMushrooms(pos - vec3(-1.0, 2.6, -1.3));
    res = min(res, mushroom);

    return res;
}

vec2 sdTemples (vec3 pos) {
 
  pos -= _TemplePosition;
  vec3 scale = _TempleScale;
  float scaleMul = min(scale.x, min(scale.y, scale.z));
  
  float res = 10000000.0;
  
  float midTemple1 = sdMidTemple(pos- vec3(1.2, 0.0, 0.0), 0.8);
  res = min(res, midTemple1);
  float midTemple2 = sdMidTemple(pos - vec3(3.0, -1.0, 0.0), 0.4);
  res = min(res, midTemple2);

  rY(pos, _TempleRotation);
  pos /= scale;


  float frontTemple = sdFrontTemple(pos);
  //float character = sdCharacter(pos);

  res = min(res, frontTemple);
  //res = min(res, character);

  pos *= scale;
  rY(pos, -_TempleRotation * 3.0);
  pos /= scale;

  float temple2 = sdBackRightTemple(pos - vec3(7.4, 0.0, 0.0));

  res = min(res, temple2);

  vec2  templeMat = vec2(res, 11 );

  vec2  templesMat = templeMat; 

  templesMat.x *= scaleMul;


  return templesMat;
}

//==========================================================================================
// Clouds
//==========================================================================================
float sdCloud( in vec3 pos, vec3 cloudPos, float rad, float spread, float phaseOffset, vec3 globalParams)
{ 
	// Add noise to the clouds
	pos += pn( pos ) * _CloudNoiseStrength;
	pos = pos - cloudPos;

	// Make us 2d-ish - My artists have confirmed me: 2D is COOL!
	pos.z /= globalParams.x;

	// Repeat the space
	float repitition = rad * 2.0 + spread;
	vec3  repSpace = pos - mod( pos - repitition * 0.5, repitition);

	// Create the overall shape to create clouds on
	pos.y +=  sin(phaseOffset + repSpace.x * 0.23  )  * globalParams.y ;

	// Creates clouds with offset on the main path
	pos.y +=  sin(phaseOffset + repSpace.x * 0.9 ) * globalParams.z;

	// repeated spheres
	pos.x = fract( (pos.x + repitition * 0.5) / repitition ) * repitition - repitition * 0.5;

	// return the spheres  
	float sphere = length(pos)- rad;
	return sphere * globalParams.x;
}

vec2 sdClouds( in vec3 pos )
{
	// Two layers of clouds. A layer in front of the big pyramid
    float c1 = sdCloud( pos, _FrontCloudsPos, _FrontCloudParams.x, _FrontCloudParams.y, _FrontCloudParams.z, _CloudGlobalParams );
    float c2 = sdCloud( pos, _FrontCloudsPos + _FrontCloudsOffsetA, _FrontCloudParamsA.x, _FrontCloudParamsA.y, _FrontCloudParamsA.z, _CloudGlobalParams );
    float c3 = sdCloud( pos, _FrontCloudsPos + _FrontCloudsOffsetB, _FrontCloudParamsB.x, _FrontCloudParamsB.y, _FrontCloudParamsB.z, _CloudGlobalParams);
    float frontClouds = min(c3, min(c1, c2));

    // This plane hides the empty spaces between the front cloud spheres. Not needed
    // for back spheres, they are covered by front spheres
  	float mainPlane = length(pos.z - _FrontCloudsPos.z) / _CloudGlobalParams.x + (pos.y - _PlaneParams.y  + sin(_PlaneParams.x + pos.x * 0.23 ) * _PlaneParams.z);// - rad;
  	frontClouds = min(mainPlane * _CloudGlobalParams.x, frontClouds);

	// Second layer behind the big Pyramid
    float c4 = sdCloud( pos, _BackCloudsPos, _BackCloudParams.x, _BackCloudParams.y, _BackCloudParams.z, _CloudBackGlobalParams );
    float c5 = sdCloud( pos, _BackCloudsPos + _BackCloudsOffsetA, _BackCloudParamsA.x, _BackCloudParamsA.y, _BackCloudParamsA.z, _CloudBackGlobalParams );
    float backClouds = min(c4,c5);
    return min_mat(vec2(frontClouds,MAT_FRONT_CLOUDS), vec2(backClouds,MAT_BACK_CLOUDS));
}

//==========================================================================================
// The main map function
//==========================================================================================
vec2 map( in vec3 pos )
{
  // vec2 temple = sdTemples(pos);
  // vec2 character = sdCharacter1(pos);
	// vec2 res = min_mat(temple, character); 
  vec2 character = sdCharacter1(pos);
	vec2 res = character;
  
  if( res.x > 0.01 )
  {
    float desert = sdTerrain(pos);

    vec2 terrain   = sdDesert(pos, desert);
    vec2 temple = sdTemples(pos);

    res	= min_mat( res, min_mat(terrain, temple) ); 
    if( terrain.x > 0.01 )
    {
      vec2 pyramid   = vec2(sdBigMountain(pos), MAT_PYRAMID);
      res = min_mat( res, pyramid );

      vec2 clouds	   = sdClouds(pos);
      res = min_mat( res, clouds );
      
    }
  }
  return res;
}

//==========================================================================================
// Used for generating normals. As it turns out that only the big mountain doesn't need
// normals. Everything else does. Hey Ho!
//==========================================================================================
vec2 mapSimple( in vec3 pos )
{
	return map( pos );
}

//==========================================================================================
// Raycasting: https://www.shadertoy.com/view/Xds3zN
//==========================================================================================
vec3 castRay(vec3 ro, vec3 rd) 
{
    float tmin = 0.1;
    float tmax = _DrawDistance;
   
    float t = tmin;
    float m = -1.0;
    float p = 0.0;
    float maxSteps = _MaxSteps;
    float j = 0.0;
    for( float i = 0.0; i < _MaxSteps; i += 1.0 )
    {
        j = i;
	    float precis = 0.0005*t;
	    vec2 res = map( ro+rd*t );
        if( res.x<precis || t>tmax ) 
        	break;
        t += res.x;
	    m = res.y;
    }
	p = j / maxSteps;
    if( t>tmax ) m=-1.0;
    return vec3( t, m, p );
}

vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*mapSimple( pos + e.xyy ).x + 
					  e.yyx*mapSimple( pos + e.yyx ).x + 
					  e.yxy*mapSimple( pos + e.yxy ).x + 
					  e.xxx*mapSimple( pos + e.xxx ).x );
}
//==========================================================================================
// Only character, flying helpers and tombs cast shadows. Only terrain recieves shadows
//==========================================================================================
float softShadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 100; ++i)
    {
      if (t >= maxt) {
          break;
      }
    	float temples = sdTemples( ro + rd * t).x;
    	float character = sdCharacter1( ro + rd * t ).x;
      float h = min(temples, character );
      if( h< 0.001 )
          return 0.1;
      res = min( res, k*h/t );
      t += h;
    }
	return res;
}

//==========================================================================================
// Sky
//==========================================================================================
vec3 sky( vec3 ro, vec3 rd )
{
    // Sun calculation
    float sunDistance = length( _SunPosition );

    vec3 delta = _SunPosition.xyz - (ro + rd * sunDistance);
    float dist 	= length(delta);

    // Turn Sun into a star, because the big mountain has a star like shape
    // coming from top
    delta.xy *= _SunStar.xy;
    float sunDist = length(delta);
    float spot = 1.0 - smoothstep(0.0, _SunSize, sunDist);
    vec3 sun = clamp(_SunScale * spot * spot * spot, 0.0, 1.0) * _SunColor.rgb;
	
	// Changing color on bases of distance from Sun. To get a strong halo around
	// the sun
   	float expDist = clamp((dist - _ExposureOffset)  * _ExposureStrength, 0.0, 1.0);
   	float expControl = pow(expDist,_ExposurePower);

    // Sky colors
    float y = rd.y;
    float zen = 1.0 - pow (min (1.0, 1.0 - y), _ZenithFallOff);
    vec3 zenithColor	= _Zenith.rgb  * zen;
    zenithColor = mix( _SunColor.rgb, zenithColor, expControl );

    float nad = 1.0 - pow (min (1.0, 1.0 + y), _NadirFallOff);
    vec3 nadirColor	= _Nadir.rgb * nad;

    float hor = 1.0 - zen - nad;
    vec3 horizonColor	= _Horizon.rgb * hor;

    // Add stars for Color Scheme 3
    float stars  = 0.0;
    return stars + (sun * _SunStar.z + zenithColor + horizonColor + nadirColor);
}

//==========================================================================================
// The rendering, based on: https://www.shadertoy.com/view/Xds3zN
//==========================================================================================
vec3 render( in vec3 ro, in vec3 rd )
{ 
	// res.z contains the iteration count / max iterations. This gives kind of a nice glow
	// effect around foreground objects. Looks particularly nice on sky, with clouds in
	// front and also on terrain. Gives rim kind of look!
	vec3 res	= castRay(ro,rd);
	vec3 skyCol = sky( ro, rd );
	vec3 col	= skyCol;

	#if defined (DEBUG_PERFORMANCE)
	return (res.z);
	#endif

	float t = res.x;
	float m = res.y;

	vec3 pos = ro + t*rd;

	// Return sky
	if( m < 0.0 )
	{
		// Bloom for the background clouds. We want Big Mountain to be engulfed with fog. So just chop out
		// areas around right and left side of BigMountain for creating fake bloom for background clouds by
		// using the iteration count needed to generate the distance function
		float rightSideCloudDist = length( (ro + rd * length(_SunPosition)) - vec3(45.0, -5.0, _SunPosition.z));
		float leftSideCloudDist = length( (ro + rd * length(_SunPosition)) - vec3(-50.0, -5.0, _SunPosition.z));
		if( rightSideCloudDist < 40.0 )
		{
			float smoothCloudBloom = 1.0 - smoothstep( 0.8, 1.0, rightSideCloudDist / 40.0);
			return col + res.z * res.z * 0.2 * smoothCloudBloom;
		}
		else if( leftSideCloudDist < 40.0 )
		{
			float smoothCloudBloom = 1.0 - smoothstep( 0.8, 1.0, leftSideCloudDist / 40.0);
			return col + res.z * res.z * 0.2 * smoothCloudBloom;
		}
        else
			return col;
	}

	float skyFog = 1.0-exp( _FogMul * t * pow(pos.y, _FogPow) );
	#if defined (DEBUG_FOG)
	return (skyFog);
	#endif

	// Render the big mountain. Keep track of it's color, so we can use it for transparency for clouds later
	vec3 pyramidCol = vec3(0.0, 0.0, 0.0);
	pyramidCol		= mix( _PyramidCol, skyCol, skyFog * 0.5  ); 

	if( TEST_MAT_LESS( m, MAT_PYRAMID) )
	{
		// Height fog, with strong fade to sky 
		float nh = (pos.y / _PyramidHeightFog.x);
		nh = nh*nh*nh*nh*nh;
		float heightFog = pow(clamp(1.0 - (nh), 0.0, 1.0), _PyramidHeightFog.y);
		heightFog		= clamp( heightFog, 0.0, 1.0 );
		pyramidCol		= mix( pyramidCol, skyCol, heightFog ); 
		return pyramidCol;       
	}

	// Calculate normal after calculating sky and big mountain
	vec3 nor = calcNormal(pos);
	// Terrain: https://archive.org/details/GDC2013Edwards
	if( TEST_MAT_LESS (m, MAT_TERRAIN_TRAIL ) )
	{
		float shadow = softShadow( pos - (rd * 0.01), _LightDir.xyz, _TerrainShadowParams.x, _TerrainShadowParams.y, _TerrainShadowParams.z);
		shadow		 = clamp( shadow + _TerrainShadowParams.w, 0.0, 1.0 );

		vec3 shadowCol = mix( shadow * _TerrainShadowColor, _TerrainDistanceShadowColor, pow(skyFog, _TerrainFogPower * _TerrainDistanceShadowPower) );

		// Strong rim lighting
		float rim	= (1.0 - saturate(dot( nor , -rd ))); 
		rim			= saturate(pow( rim, _TerrainRimPower)) *_TerrainRimStrength ; 
		vec3 rimColor	= rim * _TerrainRimColor;

		// Specular highlights
		vec3 ref		= reflect(rd, nor);
	    vec3 halfDir	= normalize(_LightDir + rd);

	    // The strong ocean specular highlight
	    float mainSpec = clamp( dot( ref, halfDir ), 0.0, 1.0 );
	    if ( TEST_MAT_LESS( m, MAT_TERRAIN ) )
	        mainSpec = pow( mainSpec, _TerrainSpecPower ) * _TerrainSpecStrength * 2.0 ;
	    else
	        mainSpec = pow( mainSpec, _TerrainSpecPower ) * _TerrainSpecStrength * 4.0;

	    float textureGlitter  = textureLod(u_Texture,pos.xz * _TerrainGlitterRep, 2.2).x * 1.15;
	    textureGlitter	= pow(textureGlitter , _TerrainGlitterPower);
	    mainSpec 		*= textureGlitter;

		// The glitter around terrain, looks decent based on rim value
	    float rimSpec	= (pow(rim, _TerrainRimSpecPower)) * textureGlitter;
	    vec3 specColor	= (mainSpec + rimSpec) * _TerrainSpecColor;
		vec3 terrainCol	= mix( (rimColor + specColor * shadow) + _TerrainCol, skyCol, pow(skyFog, _TerrainFogPower) ) + res.z * 0.2;  

		// maybe add a fake AO from player, just a sphere should do!
		return mix( shadowCol, terrainCol, shadow );
	}

	// Clouds
	if( TEST_MAT_LESS (m, MAT_FRONT_CLOUDS ) )
	{
		// Modify the normals so that they create strong specular highlights
		// towards the top edge of clouds
		nor				= normalize( nor + _CloudNormalMod);
		float dotProd	= dot( nor, vec3(1.0,-3.5,1.0) );

		float spec		=  1.0 -  clamp( pow(dotProd, _CloudSpecPower), 0.0, 1.0 );
		spec 			*= 2.0;
		vec3 cloudCol	= spec * _CloudSpecCol + _CloudCol;

		// Transparency for mountain
		if( sdBigMountain( pos + (rd * t * _CloudPyramidDistance)) < 0.2 )
	 	{
	 		cloudCol = mix( pyramidCol, cloudCol, _CloudTransparencyMul ); 
		}

		// Mixing for backdrop mountains. Backdrop mountains take more color from Sky. Foreground mountains
		// retain their own color values, so I can adjust their darkness
		vec3 inCloudCol = mix(cloudCol, _BackCloudCol + skyCol * 0.5 + spec * _BackCloudSpecCol, MAT_FRONT_CLOUDS - m);
		return mix( inCloudCol , skyCol, skyFog * _CloudFogStrength );    
	}

	// Tombs
	if( TEST_MAT_LESS(m, MAT_TOMB_SCARF ) )
	{
		// Simple strong diffuse
		float diff	= clamp(dot(nor,_LightDir) + 1.0, 0.0, 1.0);
		vec3 col	= mix( _TombMainColor, _TombScarfColor * 2.0, m - MAT_TOMB );
		return mix( diff * col, skyCol, skyFog);
	}

  // Character
	if( TEST_MAT_GREATER (m, MAT_CHARACTER_BASE ) )
	{
    float diff = _CharacterDiffScale * clamp( dot( nor, _LightDir ), 0.0, 1.0 );

    // Why did I fudge these normals, I can't remember. It does look good though, so keep it :)
    nor		= normalize( nor + vec3(0.3,-0.1,1.0));
    nor.y	*= 0.3;

    float fres	= pow( clamp( 1.0 + dot(nor,rd) + 0.75, 0.0, 1.0), _CharacterFrePower ) * _CharacterFreScale;
    vec3 col	= _CharacterMainColor;

    // Just base color
    if( TEST_MAT_LESS( m, MAT_CHARACTER_BASE) )
    {
      // Add sand fade to legs. Mixing terrain color at bottom of legs
			float heightTerrainMix	= pow((pos.y / _CharacterHeightTerrainMix.x), _CharacterHeightTerrainMix.y);
			heightTerrainMix		= clamp( heightTerrainMix, 0.0, 1.0 );
			col	= mix( _CharacterMainColor, _CharacterTerrainCol, heightTerrainMix );
    }
    // Main Cloak
    else if( TEST_MAT_LESS( m,MAT_CHARACTER_MAIN_CLOAK) )
    {
      col = _CharacterCloakDarkColor;
      return col;
    }
    else if( TEST_MAT_LESS( m,MAT_CHARACTER_HAIR)) 
    {
      col = vec3(1.0, 1.0, 1.0);
      return col;
    }
    else if( TEST_MAT_LESS( m,MAT_CHARACTER_DRESS)) 
    {
      col = _CharacterMainColor;
      return col;
    }
    else {
      col = _CharacterMainColor;
      return col;
    }
  }
	return vec3( clamp(col * 0.0,0.0,1.0) );
}


float rand(float n)
{
	return fract(sin(n) * 43758.5453123);
}

float noise(float p)
{
	float fl = floor(p);
	float fc = fract(p);
    fc = fc*fc*(3.0-2.0*fc);
    return mix(rand(fl), rand(fl + 1.0), fc);
}

float distanceFog(float d) {
    float fog_maxdist = 50.f;
    float fog_mindist = 18.f;
    if (d > fog_maxdist) {
        return 1.f;
    }
    else if (d < fog_mindist) {
        return 0.f;
    }
    else {
        float fog_factor = 1.0 - (fog_maxdist - d) / (fog_maxdist - fog_mindist);
        return fog_factor;
    }
    return 0.f;
}

void main() {
  // Move camera using noise. This is probably quite expensive way of doing it :(
	float unitNoiseX = (noise(u_Time * 0.01 * _CameraMovement.w ) * 2.0)  - 1.0;
	float unitNoiseY = (noise((u_Time * 0.01 * _CameraMovement.w ) + 32.0) * 2.0)  -1.0;
	float unitNoiseZ = (noise((u_Time * 0.01 * _CameraMovement.w ) + 48.0) * 2.0)  -1.0;
	vec3 ro = _CameraPos + vec3(unitNoiseX, unitNoiseY, unitNoiseZ) * _CameraMovement.xyz;


	vec3 screenRay		= vec3(gl_FragCoord.xy / u_Dimensions.xy, 1.0);
	vec2 screenCoord	= screenRay.xy * 2.0 - 1.0;

	// Screen ray frustum aligned
	screenRay.xy = screenCoord * _CameraFOV.xy;
    screenRay.x			*= 1.35;
	screenRay.z  = -_CameraFOV.z;
	screenRay /= abs( _CameraFOV.z); 

  // In camera space
	vec3 rd = normalize(mul( _CameraInvViewMatrix, vec4(screenRay,0.0))).xyz;

	// Do the render
	vec4 col = vec4(render(ro, rd), 0.0);

	vec3 res = castRay(ro,rd);
	float t = res[0];
	vec3 isect = ro + t * rd;
	// No it does not need gamma correct or tone mapping or any other effect that you heard about
	// and thought was cool. This is not realistic lighting

	// vignette
	float vig = pow(1.0 - 0.4 * dot(screenCoord, screenCoord), 0.6) * 1.25;
	vig = min( vig, 1.0);
	col *= vig;

	// Distance Fog
	float d = distance(isect, u_Eye);
    float fogFactor = distanceFog(d);

	vec4 tmpColor = vec4(col.xyz,1);
	tmpColor = mix(tmpColor, vec4(RGB(1, 0.96926, 0.84853),1.0), fogFactor);
	// Final color
	out_Col =  vec4(col.xyz,1);
  //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}

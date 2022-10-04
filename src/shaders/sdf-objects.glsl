

float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float bumpyPlaneSDF(vec3 queryPos, float height, float u_Time)
{
    return queryPos.y - height + (0.3*(sin(queryPos.x + 5.4) * cos(queryPos.z)));
}

float rand_3(vec2 p)
{
    return fract(sin(dot(p.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float value_noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 s = smoothstep(0.0, 1.0, f);
    float nx0 = mix(rand_3(i + vec2(0.0, 0.0)), rand_3(i + vec2(1.0, 0.0)), s.x);
    float nx1 = mix(rand_3(i + vec2(0.0, 1.0)), rand_3(i + vec2(1.0, 1.0)), s.x);
    return mix(nx0, nx1, s.y);
}


float bumpyPlaneSDF2(vec3 p)
{
    const int no = 3;
    float tot = 0.0;
    vec2 q = p.xz * 0.35;
    float a = 0.5;
    float f = 1.0;
    for (int i = 0; i < no; ++i)
    {
        tot += value_noise(q * f) * a;
        a *= 0.5;
        f *= 2.5;
        q = q * mat2(0.5, -0.866, 0.866, 0.5) * 0.65;
        q += vec2(2.5, 4.8);
    }

    float d1 = p.y - tot * 2.0;

    return d1;
}

float cubeSDF(vec3 query_position, vec3 position, vec3 dims )
{
    vec3 d = abs(query_position - position) - dims;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
    vec3 pa = queryPos - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

// based on https://www.shadertoy.com/view/Ntd3DX
float pyramidSDF(vec3 q_position, vec3 position, float halfWidth, float halfDepth, float halfHeight) {
    q_position -= position;
    q_position.xz = abs(q_position.xz);

    // bottom
    float s1 = abs(q_position.y) - halfHeight;
    vec3 base = vec3(max(q_position.x - halfWidth, 0.0), abs(q_position.y + halfHeight), max(q_position.z - halfDepth, 0.0));
    float d1 = dot(base, base);

    vec3 q = q_position - vec3(halfWidth, -halfHeight, halfDepth);
    vec3 end = vec3(-halfWidth, 2.0 * halfHeight, -halfDepth);
    vec3 segment = q - end * clamp(dot(q, end) / dot(end, end), 0.0, 1.0);
    float d = dot(segment, segment);

    // side
    vec3 normal1 = vec3(end.y, -end.x, 0.0);
    float s2 = dot(q.xy, normal1.xy);
    float d2 = d;
    if (dot(q.xy, -end.xy) < 0.0 && dot(q, cross(normal1, end)) < 0.0) {
        d2 = s2 * s2 / dot(normal1.xy, normal1.xy);
    }
    // front/back
    vec3 normal2 = vec3(0.0, -end.z, end.y);
    float s3 = dot(q.yz, normal2.yz);
    float d3 = d;
    if (dot(q.yz, -end.yz) < 0.0 && dot(q, cross(normal2, -end)) < 0.0) {
        d3 = s3 * s3 / dot(normal2.yz, normal2.yz);
    }
    return sqrt(min(min(d1, d2), d3)) * sign(max(max(s1, s2), s3));
}



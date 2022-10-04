


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

// non smooth combinations https://www.ronja-tutorials.com/post/035-2d-sdf-combination/

float flatUnion(float shape1, float shape2){
    return min(shape1, shape2);
}

float flatIntersection(float shape1, float shape2){
    return max(shape1, shape2);
}

float flatSubtraction(float base, float subtraction){
    return flatIntersection(base, -subtraction);
}

//float flatInterpolatation(float shape1, float shape2, float amount){
//  return lerp(shape1, shape2, amount);
//}
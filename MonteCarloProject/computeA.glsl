
#version 430 core
#define PI 3.1415926535897932384626433832795
layout (local_size_x = 10, local_size_y = 10, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D imgOutput;

layout (location = 0) uniform float t;                 /** Time */



//my desmos to explain https://www.desmos.com/calculator/mnlfjyluor
//         |
//         |
//        \/
//I smplified it to the version I actually implemented here: https://www.desmos.com/calculator/opbd5d3vv5


//also this wave goes (0,0) -> (0.25,1) -> (.5,0) but thats not why I call it better
//I call it better because its behavior doesnt change when x -> infinity, whereas glsl sin changes behavior for large x
float betterSin(float x){

    float F = fract(x);
    float F2 = mod(F, .5);
    
    float f = 16. * F2 * (.5 - F2);
    
    float s = .5 - F;
    s /= abs(s);
    
    return f * s;
    
}


void main() {
    vec4 value = vec4(0.0, 0.0, 0.0, 1.0);
    ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
    
    vec2 uv = vec2(texelCoord)/(gl_NumWorkGroups.xy * gl_WorkGroupSize.xy);
    uv *= 2.;
    uv -= 1.;
    
    uv *= 2.;
    
    uv.x += t;


    float speed = 100;
    // the width of the texture
    float width = 1000;

    //value.x = mod(float(texelCoord.x) + t * speed, width) / (gl_NumWorkGroups.x * gl_WorkGroupSize.x);
    //value.y = float(texelCoord.y)/(gl_NumWorkGroups.y*gl_WorkGroupSize.y);
    
    vec4 col = vec4(0.);
    
    
    float offset = 1e5;
    
    uv.x += offset;
    
    
    //green is my sine
    if(distance(uv, vec2(uv.x, betterSin(uv.x))) < 0.05){
        
        col = vec4(0., 1., 0., 0.);
    
    }
    
    //red is glsl sine
    if(distance(uv, vec2(uv.x, sin(2. * PI * uv.x))) < 0.05){
        
        col += vec4(1., 0., 0., 0.);
        
    }
    
    
    imageStore(imgOutput, texelCoord, col);
}




/*
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    vec2 uv = fragCoord/iResolution.xy;
    uv *= 2.;
    uv -= 1.;
    
    uv *= 2.;
    
    uv.x += iTime;
    
    vec4 col = vec4(0.);
    
    
    float offset = 1e6;
    
    uv.x += offset;
    
    
    //green is my sine
    if(distance(uv, vec2(uv.x, betterSin(uv.x))) < 0.05){
        
        col = vec4(0., 1., 0., 0.);
    
    }
    
    //red is glsl sine
    if(distance(uv, vec2(uv.x, sin(2. * PI * uv.x))) < 0.05){
        
        col += vec4(1., 0., 0., 0.);
        
    }
    
    
    
    fragColor = col;
}
*/
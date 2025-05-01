#version 430 core

layout (local_size_x = 10, local_size_y = 10, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D imgOutput;

layout (location = 0) uniform float t;                 /** Time */


#define pi 3.1415926535897932
#define halfPi 1.57079632679

float hash3(vec2 xy){
    xy = mod(xy, .19);
    float h = dot(xy.yyx,vec3(.013, 27.15, 2027.3));
    h *= h;
    h *= fract(h);
    
    return fract(h);
}


vec2 rotate(vec2 v, float theta){
    mat2 rot;
    rot[0] = vec2(cos(theta), -sin(theta));
    rot[1] = vec2(sin(theta), cos(theta));
    
    
    return rot * v;
}

vec3 rotate3D(vec3 v, float phi, float theta){
    mat3 rot = mat3(
        vec3( cos(phi)*cos(theta), sin(phi), cos(phi)*sin(theta)),
        vec3( -sin(phi)*cos(theta), cos(phi), -sin(phi)*sin(theta)),
        vec3( -sin(theta), 0., cos(theta))
    );
    
    
    return rot * v;
}
vec3 inverseRotate3D(vec3 v, float phi, float theta){
    mat3 rot = mat3(
        vec3( cos(phi)*cos(theta), sin(phi), cos(phi)*sin(theta)),
        vec3( -sin(phi)*cos(theta), cos(phi), -sin(phi)*sin(theta)),
        vec3( -sin(theta), 0., cos(theta))
    );
    
    mat3 inv = inverse(rot);
    
    return inv * v;
}

float cloudNoise1(vec2 frag, float scale){
    
    frag *= scale;
    
    frag = floor(frag);
    
    frag += 1000.0f;
    
    vec2 frag2 = rotate(frag, frag.y);
    vec2 frag3 = rotate(frag, frag.x);    
    
    
    
    return fract(frag2.y - frag3.x);// * frag2.y;
}


//gets the square of the closest distance on ray to point
//total of 15 operations
float pointRayDist(vec3 rayD, vec3 rayO, vec3 p){
    vec3 toP = p - rayO;
    
    
    float d = dot(rayD, toP);
    
    float l2 = dot(toP, toP) - (d * d);
    
    return l2;
}

//returns the closest point on ray with dist squared to point as first vec3
// and the distance squared of the ray point to input
// point as the fourth value
// total of 18 operations (could be 11 without l2)
vec4 pointRay(vec3 rayD, vec3 rayO, vec3 p){
    vec3 toP = p - rayO;
    
    float d = dot(rayD, toP);
    
    float l2 = dot(toP, toP) - (d * d);
    
    vec3 rp = (d * rayD) + rayO;
    
    return vec4(rp, l2);
}

//see desmos "Closest Point On Ray To Point With Radius"
// if the point is the center of a sphere with radius r
// much more expensive because of sqrt though
vec4 pointRayWithRadius(vec3 rayD, vec3 rayO, vec3 p, float r){
    vec3 toP = p - rayO;
    
    float d = dot(rayD, toP);
    
    float l2 = dot(toP, toP) - (d * d);
    
    d -= sqrt((r*r) - l2);
    
    vec3 rp = (d * rayD) + rayO;
    
    return vec4(rp, l2);
}

vec3 CartToSph(vec3 c){
    float r = length(c);
    return vec3(r, atan(c.y, c.x), acos(c.z / r));
}


float AtmosphereDensity(float x, float x0, float a){
    float r = x - x0;
    float fx = 1. / (1. + (a * abs(pow(abs(r), 1.6))));
    float gx = .1 * (tanh(-1. * pow(a, 1. / 3.) * r) + 1.5);
    float hx = .5 * (tanh(3. * (x - (.5 * x0))) + 1.5);
    
    return fx + (gx * hx);
}

//this is the negative potential function if you consider 
// the AtmosphereDensity as a field strength
//The negative of the potential function is proportional to the
// energy at a point, or in this case, the amount of light scattered
float NegativeScatteringPotential(float r, float R, float a){
    float r1 = r - R;
    float roota = sqrt(a);
    return (1. / (roota)) * (halfPi - atan(r1 * roota));
    
}

float hillFunction(float x, float x0, float a){
    float r = x - x0;
    return 1. / (1. + (a * (r * r)));
}













void main() {
    vec4 value = vec4(0.0, 0.0, 0.0, 1.0);
    ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
    vec2 fragCoord = vec2(texelCoord);
    vec2 iResolution = vec2(gl_NumWorkGroups.xy * gl_WorkGroupSize.xy);

    vec2 uv = fragCoord/iResolution;
    vec2 prop = iResolution / iResolution.y;
    //prop.y *= .8;
    vec2 uvc = prop * (2. * (uv - 0.5));
    vec2 uvcHat = normalize(uvc);
    
    vec4 col = vec4(0.);
    
    
    
    float oneThird = 1. / 3.;
    float root3 = sqrt(3.);
    uvc.x *= -1.;
    vec3 rayD = vec3(sqrt(1. - (oneThird * dot(uvc, uvc))), uvc.x / root3, uvc.y / root3);
    
    
    float phi = .3 * (t - 10.);
    phi -= halfPi;
    float theta = .5 * (t - 10.);
    
    //phi = 1.5 * pi;
    //theta = 0.;
    theta = .4 * sin(theta);
    
    float camCL = -4. * (.2 * sin(t * .5) + 1.);
    vec3 camC = camCL * vec3(1., 0., 0.);
    vec3 camForward = vec3(1., 0., 0.);
    vec3 camUp = vec3(0., 0., 1.);
    vec3 camRight = vec3(0., -1., 0.);
    
    
    
    rayD = rotate3D(rayD, phi, theta);
    
    camC = rotate3D(camC, phi, theta);
    camUp = rotate3D(camUp, phi, theta);
    camRight = rotate3D(camRight, phi, theta);
    camForward = rotate3D(camForward, phi, theta);
    

    vec3 lightDir = normalize(vec3(-1., 0., 0.));
    
    
    
    //surface #####
    vec4 rayPoint = pointRayWithRadius(rayD, camC, vec3(0.), 1.);
    
    vec3 p = rayPoint.xyz;
    float l2 = rayPoint.w;
    
    
    float lightDot = max(dot(normalize(p), -lightDir) + .05, 0.);
    
    //if we hit the planet then the rayPoint dist will be <= 1.
    float hitPlanet = clamp(1. - floor(l2), 0., 1.);

    vec4 groundColor = vec4(0.802, .41, .18, 1.);

    col = hitPlanet * lightDot * groundColor;

    //end surface #####




    //atmosphere #####
    rayPoint = pointRay(rayD, camC, vec3(0.));
    p = rayPoint.xyz;
    l2 = rayPoint.w;
    
    lightDot = mix(max(dot(normalize(p), -lightDir) + .2, 0.), lightDot, hitPlanet);
    
    
    //tint towards blue at dawn/dusk (mars atmosphere)
    vec4 atmoTint = mix(vec4(.1, .6, 2.1, 1.), vec4(1.), pow(lightDot, .25));
    
   
    //add atmosphere
    col += atmoTint * lightDot * AtmosphereDensity(l2, 1.0, 100.) * vec4(.85, .6, .5, 1.) * 2. / mix(l2 * l2, 1., hitPlanet) * .4;
    col += atmoTint * lightDot * NegativeScatteringPotential(l2, 1.05, 100.) * vec4(.6, .5, .4, 1.) * 3.;
    
    //end atmosphere #####



    //suggestion from @bloodnok
    vec3 colGamma = pow(col.rgb, vec3(1.0/2.2));
    
    col.rgb = mix(col.rgb, colGamma, hitPlanet * lightDot);
    
    imageStore(imgOutput, texelCoord, col);
}
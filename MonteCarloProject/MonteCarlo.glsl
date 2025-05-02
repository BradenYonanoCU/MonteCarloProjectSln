#version 430 core

layout (local_size_x = 10, local_size_y = 10, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D imgOutput;

layout (location = 0) uniform float t;                 /** Time */

layout (location = 1) uniform int frame;


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

    if(dot(rayD, normalize(toP)) < 0.){
        
        return vec4(1000., 1000., 1000., 10. * r);
        
    }
    
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


vec3 RaycastPlane(vec3 rayD, vec3 rayO, vec3 planeC, vec3 planeN, vec2 planeExt){
    
    vec3 Intersection = vec3(100000.);

    vec3 TangentUp = normalize(cross(planeN, vec3(0., 0., 1.)));
    vec3 TangentRight = normalize(cross(planeN, TangentUp));

    if(dot(rayD, planeN) > 0.){

        return Intersection;
    
    }
    else{
        
        float vt = -(dot(rayO - planeC, planeN)) / dot(rayD, planeN);
        Intersection = (rayO + (vt * rayD));
        
        vec3 toI = Intersection - planeC;

        float dU, dR;
        dU = abs(dot(TangentUp, toI));
        dR = abs(dot(TangentRight, toI));

        // if outside of plane then set Intersection to a large number (indicating no intersection)
        if(dU > planeExt.y || dR > planeExt.x){
            
            Intersection = vec3(100000.);
            
        }

        
    }


    return Intersection;
    
}


vec3 DiffuseMaterialBounce(vec3 normal, vec3 randomSeed){
    
    vec2 r = vec2(hash3(randomSeed.xy + t), hash3(randomSeed.zx + t));

    /*
    float theta = acos(sqrt(r.x));
    float phi = 2. * pi * r.y;



    vec3 randomBounce = rotate3D(normal, phi, theta);//vec3(sqrt(1. - r.x) * cos(2. * pi * r.y), sqrt(1. - r.x) * sin(2. * pi * r.y), sqrt(r.x));


    return randomBounce;
    */

    float phi = 2.0 * pi * r.x;
    float cosTheta = sqrt(1.0 - r.y);
    float sinTheta = sqrt(r.y);
    vec3 dv = vec3(cos(phi) * cosTheta, sin(phi) * cosTheta, sinTheta);

    vec3 tangent = normalize(abs(normal.z) < 0.999 ? cross(normal, vec3(0.,0.,1.)) : cross(normal, vec3(0.,1.,0.)));
    vec3 bitangent = cross(normal, tangent);
    mat3 tangentFrame = mat3(tangent, bitangent, normal);

    return normalize(tangentFrame * dv);
}




//returns resulting ray location, new ray direction (after reflecting or bouncing or diffracting), then new net ray color
mat4 RayCast(vec3 rayD, vec3 rayO, vec3 lightO){
    
    float minD = 1000000.0f;
    vec3 newRayD = rayD;
    vec3 newRayO = rayO;
    vec3 newNormal = vec3(0., 0., 1.);
    vec4 newCol = vec4(0.);



    vec3 sphereLoc = vec3(0.);

    //First ray trace the sphere
    vec4 rayPoint = pointRayWithRadius(rayD, rayO, sphereLoc, 1.);

    vec4 rayLight = pointRayWithRadius(rayD, rayO, lightO, .2);


    float wallsDist = 1.5;
    float wallsSize = 2.0;

    vec3 rayPlaneFloor = RaycastPlane(rayD, rayO, vec3(0., 0., -1.1), normalize(vec3(0.05, 0.05, 1.)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneXP = RaycastPlane(rayD, rayO, vec3(wallsDist, 0., 0.), normalize(vec3(-1., 0.05, 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneXN = RaycastPlane(rayD, rayO, vec3(-wallsDist * 10., 0., 0.), normalize(vec3(1., 0.05, 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneYP = RaycastPlane(rayD, rayO, vec3(0., wallsDist, 0.), normalize(vec3(0.05, -1., 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneYN = RaycastPlane(rayD, rayO, vec3(0., 10. * -wallsDist, 0.), normalize(vec3(0.05, 1., 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneCeil = RaycastPlane(rayD, rayO, vec3(0., 0., 1.5), normalize(vec3(0.05, 0.05, -1.)), vec2(wallsSize, wallsSize));

    float dSph = distance(rayO, rayPoint.xyz);
    float dLi = distance(rayO, rayLight.xyz);
    float dPF = distance(rayO, rayPlaneFloor);
    float dPXP = distance(rayO, rayPlaneXP);
    float dPXN = distance(rayO, rayPlaneXN);
    float dPYP = distance(rayO, rayPlaneYP);
    float dPYN = distance(rayO, rayPlaneYN);
    float dPC = distance(rayO, rayPlaneCeil);

    minD = min(dSph, min(dPF, min(dPXP, min(dPXN, min(dPYP, min(dPYN, min(dPC, dLi)))))));
    //minD = min(dSph, min(dPF, dLi));

    //make sure that if nothing is hit, then no min dist passes the differential check
    if (minD > 50.){
        
        minD = -1.;

    }

    vec4 addCol = vec4(0.);

    float diffuseReflectance = .4;

    if(abs(minD - dSph) < 0.05){
        
        addCol = vec4(.1);//vec4(dot(normalize(rayPoint.xyz), -lightD));
        
        vec3 normal = normalize(rayPoint.xyz - sphereLoc);

        newRayD = normalize(rayD - (2. * dot(rayD, normal) * normal));
        newRayO = rayPoint.xyz + .001 * newRayD;
        newNormal = normal;

    }

    else if(abs(minD - dPF) < 0.05){
        
        addCol = diffuseReflectance * vec4(1., 1., 0., .8);
        
        newRayD = DiffuseMaterialBounce(vec3(0., 0., 1.), rayD);
        newRayO = rayPlaneFloor + newRayD * .001;
        newNormal = vec3(0., 0., 1.);

    }

    else if(abs(minD - dPXP) < 0.05){
        
        addCol = diffuseReflectance * vec4(1.);
        
        newRayD = DiffuseMaterialBounce(vec3(-1., 0., 0.), rayD);
        newRayO = rayPlaneXP + newRayD * .001;
        newNormal = vec3(-1., 0., 0.);

    }
    else if(abs(minD - dPXN) < 0.05){
        
        addCol = diffuseReflectance * vec4(.8);

        newRayD = DiffuseMaterialBounce(vec3(1., 0., 0.), rayD);
        newRayO = rayPlaneXN + newRayD * .001;
        newNormal = vec3(1., 0., 0.);
    }
    else if(abs(minD - dPYP) < 0.05){
        
        addCol = diffuseReflectance * vec4(.8);

        newRayD = DiffuseMaterialBounce(vec3(0., -1., 0.), rayD);
        newRayO = rayPlaneYP + newRayD * .001;
        newNormal = vec3(0., -1., 0.);
        
    }
    else if(abs(minD - dPYN) < 0.05){
        
        addCol = diffuseReflectance * vec4(0., 0., 1., .8);

        newRayD = DiffuseMaterialBounce(vec3(0., 1., 0.), rayD);
        newRayO = rayPlaneYN + newRayD * .001;
        newNormal = vec3(0., 1., 0.);
        
    }
    else if(abs(minD - dPC) < 0.05){
        
        addCol = diffuseReflectance * vec4(.8);

        newRayD = DiffuseMaterialBounce(vec3(0., 0., -1.), rayD);
        newRayO = rayPlaneCeil + newRayD * .001;
        newNormal = vec3(0., 0., -1.);
        
    }
    else if(abs(minD - dLi) < 0.05){
        
        addCol = vec4(1.);

        vec3 normal = normalize(rayPoint.xyz - lightO);

        newRayD = DiffuseMaterialBounce(normal, rayD);
        newRayO = rayPlaneCeil + newRayD * .001;
        newNormal = normal;
    }

    //newCol = mix(newCol, addCol, 1. / float(frame));
    newCol = addCol;



    mat4 outData = mat4(
    vec4(newRayD, 0.),
    vec4(newRayO, 0.),
    vec4(newNormal, 0.),
    newCol
    );

    return outData;
}









void main() {
    vec4 value = vec4(0.0, 0.0, 0.0, 1.0);
    ivec2 texelCoord = ivec2(gl_GlobalInvocationID.xy);
    vec2 fragCoord = vec2(texelCoord);
    vec2 iResolution = vec2(gl_NumWorkGroups.xy * gl_WorkGroupSize.xy);

    vec2 prop = iResolution.xy / iResolution.y;
    vec4 col = imageLoad(imgOutput, texelCoord);
    
    if(frame == 0){
        
        col = vec4(0., 0., 0., 1.);
        
        
    }


    /*
    vec2 uv = fragCoord/iResolution;
    
    
    vec2 uvc = prop * (2. * (uv - 0.5));
    vec2 uvcHat = normalize(uvc);
    
    

    
    
    
    
    
    uvc.x *= -1.;
    //vec3 rayD = vec3(sqrt(1. - (oneThird * dot(uvc, uvc))), uvc.x / root3, uvc.y / root3);
    
    */
    float oneThird = 1. / 3.;
    float root3 = sqrt(3.);

    vec2 uv = fragCoord / iResolution.xy;
    vec2 uvc = 2.0 * (uv - 0.5);
    uvc.x *= iResolution.x / iResolution.y;

    vec3 rayD = normalize(vec3(1.0, uvc.x, uvc.y));
    


    float camTime = 0.;

    float phi = .3 * (camTime);
    //phi -= halfPi;
    float theta = .5 * (camTime);
    
    //phi = 1.5 * pi;
    //theta = 0.;
    theta = .4 * sin(theta);
    
    float camCL = -5.;
    vec3 camC = camCL * vec3(1., 0., 0.);
    vec3 camForward = vec3(1., 0., 0.);
    vec3 camUp = vec3(0., 0., 1.);
    vec3 camRight = vec3(0., -1., 0.);
    
    
    
    rayD = rotate3D(rayD, phi, theta);
    
    camC = rotate3D(camC, phi, theta);
    camUp = rotate3D(camUp, phi, theta);
    camRight = rotate3D(camRight, phi, theta);
    camForward = rotate3D(camForward, phi, theta);
    

    vec3 lightO = vec3(-1., 1., 1.);
    vec3 lightDir = normalize(-lightO);
    
    








    vec4 totalColor = vec4(0.);
    
    mat4 rayOne = RayCast(rayD, camC, lightO);
    mat4 rayTwo = RayCast(rayOne[0].xyz, rayOne[1].xyz, lightO);

    vec3 ltc = normalize(rayTwo[1].xyz - lightO);

    mat4 lightRay = RayCast(ltc, lightO + (.91 * ltc), lightO);

    float distLtoR = distance(lightO, rayTwo[1].xyz);
    float distLtoL = distance(lightO, lightRay[1].xyz);

    if(abs(distLtoR - distLtoL) < .01){
        
        float attenuation = max(0., dot(-ltc, rayTwo[2].xyz));// * max(0., dot(ltc, lightDir));
        totalColor = lightRay[3] * rayTwo[3] * rayOne[3];
        
    }
    else{
        //totalColor = vec4(1., 0., 0., 0.);
    }

    
    
    //col = mix(col, totalColor, 1. / float(frame + 1));
    col += totalColor / (float(frame + 1));


    //col = vec4(dot(rayD, vec3(0., 0., -1.)));

    imageStore(imgOutput, texelCoord, col);
}
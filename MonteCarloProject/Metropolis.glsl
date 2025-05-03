#version 430 core

layout (local_size_x = 10, local_size_y = 10, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D imgOutput;

layout (location = 0) uniform float t;                 /** Time */

layout (location = 1) uniform int frame;


#define pi 3.1415926535897932
#define halfPi 1.57079632679

#define maxPath 8
#define N 6




float hash3(vec2 xy){
    xy = mod(xy, .19);
    float h = dot(xy.yyx,vec3(.013, 27.15, 2027.3));
    h *= h;
    h *= fract(h);
    
    return fract(h);
}


bool Chance(float probability, vec2 seed){
    
    return hash3(seed) < probability;
    
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

vec4 pointRayWithRadiusBackside(vec3 rayD, vec3 rayO, vec3 p, float r){
    vec3 toP = p - rayO;
    
    float d = dot(rayD, toP);

    if(dot(rayD, normalize(toP)) < 0.){
        
        return vec4(1000., 1000., 1000., 10. * r);
        
    }
    
    float l2 = dot(toP, toP) - (d * d);
    
    //THIS (the + vs -) is the only difference with the frontside function. See my desmos https://www.desmos.com/calculator/qamknlzsfw
    d += sqrt((r*r) - l2);
    
    vec3 rp = (d * rayD) + rayO;
    
    return vec4(rp, l2);
}

vec3 CartToSph(vec3 c){
    float r = length(c);
    return vec3(r, atan(c.y, c.x), acos(c.z / r));
}






















vec3 RaycastPlane(vec3 rayD, vec3 rayO, vec3 planeC, vec3 planeN, vec2 planeExt){
    
    vec3 Intersection = vec3(100000.);

    vec3 TangentUp = normalize(cross(planeN, vec3(0., 0., 1.)));
    vec3 TangentRight = normalize(cross(planeN, TangentUp));

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
    else if( dot(rayD, normalize(Intersection - rayO)) < 0.){
            
        Intersection = vec3(100000.);

    }


    return Intersection;
    
}

void RaycastGlassSphere(inout vec3 rayD, inout vec3 rayO, out vec3 surfaceN, vec3 sphereC, float sphereR){
    
    //first trace against the sphere
    vec4 initialCast = pointRayWithRadius(rayD, rayO, sphereC, sphereR);

    //if no intersection then just return large vector
    if(length(initialCast) > 100.){
        
         rayO = vec3(1000.);
         return;

    }



    //decide whether this trace is going to refract or reflect upon hitting the sphere
    float random = hash3(vec2(t, rayD.x * initialCast.y));
    
    //normal is just direction to intersection from center
    vec3 normal = normalize(initialCast.xyz - sphereC);

    //in less than .5, then reflect
    if(random < .3){
        
        rayD = reflect(rayD, normal);
        rayO = initialCast.xyz;
        surfaceN = normal;
        return;

    }


    

    
    //air is ~1. and glass is ~1.6 so air/glass = 1. / 1.6
    float ior = 1.6;
    


    
    
    vec3 internalD = refract(rayD, normal, 1. / ior);

    //do a cast to the backside of the sphere along refraction direction
    vec4 internalCast = pointRayWithRadiusBackside(internalD, initialCast.xyz, sphereC, sphereR);

    //new normal is like before
    normal = -normalize(internalCast.xyz - sphereC);

    rayO = internalCast.xyz;
    

    //total internal reflection?
    if(dot(internalD, normal) > cos(asin(1. / ior))){

        //finally set the new refracted ray direction and ray origin
        rayD = reflect(internalD, normal);
        surfaceN = normal;

        //finally set the new refracted ray direction and ray origin
        //rayD = refract(internalD, normal, ior);
        //surfaceN = -normal;

        //imgOutput = vec4(0., 1., 0., 1.);

    }
    //else exit refraction
    else{
        
        //finally set the new refracted ray direction and ray origin
        rayD = refract(internalD, normal, 1.6);
        surfaceN = -normal;

    }

    
}



vec3 DiffuseMaterialBounce(vec3 normal, vec3 randomSeed){
    
    vec2 r = vec2(hash3(randomSeed.xy + t), hash3(randomSeed.zx + t));

    float phi = 2.0 * pi * r.x;
    float cosTheta = sqrt(1.0 - r.y);
    float sinTheta = sqrt(r.y);
    vec3 dv = vec3(cos(phi) * cosTheta, sin(phi) * cosTheta, sinTheta);

    vec3 tangent = normalize(abs(normal.z) < 0.999 ? cross(normal, vec3(0.,0.,1.)) : cross(normal, vec3(0.,1.,0.)));
    vec3 bitangent = cross(normal, tangent);
    mat3 tangentFrame = mat3(tangent, bitangent, normal);

    return normalize(tangentFrame * dv);
}


float DiffuseAttenuation(vec3 p, vec3 n, vec3 lightO){
    
    float attenuation = max(0., dot(normalize(lightO - p), n));
    
    float l = length(p - lightO);
    attenuation /= (l * l);

    attenuation += .5;

    return attenuation;
}


vec4 DiffuseBRDF(vec3 rayIncident, vec3 rayDeparting, vec3 normal, vec3 color, float intensity){

    vec3 outColor = color / pi;

    float luminosity = dot(outColor, vec3(0.2127, 0.7152, 0.0722));

    return vec4(outColor, luminosity);

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

    vec3 glassD, glassP, glassN;
    glassD = rayD;
    glassP = rayO;
    RaycastGlassSphere(glassD, glassP, glassN, vec3(-2., .6, -.2), .5);



    float wallsDist = 1.5;
    float wallsSize = 5.0;

    vec3 rayPlaneFloor = RaycastPlane(rayD, rayO, vec3(0., 0., -1.1), normalize(vec3(0.05, 0.05, 1.)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneXP = RaycastPlane(rayD, rayO, vec3(wallsDist, 0., 0.), normalize(vec3(-1., 0.05, 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneXN = RaycastPlane(rayD, rayO, vec3(-wallsDist * 10., 0., 0.), normalize(vec3(1., 0.05, 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneYP = RaycastPlane(rayD, rayO, vec3(0., wallsDist, 0.), normalize(vec3(0.05, -1., 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneYN = RaycastPlane(rayD, rayO, vec3(0., 10. * -wallsDist, 0.), normalize(vec3(0.05, 1., 0.05)), vec2(wallsSize, wallsSize));
    vec3 rayPlaneCeil = RaycastPlane(rayD, rayO, vec3(0., 0., 1.5), normalize(vec3(0.05, 0.05, -1.)), vec2(wallsSize, wallsSize));

    float dSph = distance(rayO, rayPoint.xyz);
    float dPF = distance(rayO, rayPlaneFloor);
    float dPXP = distance(rayO, rayPlaneXP);
    float dPXN = distance(rayO, rayPlaneXN);
    float dPYP = distance(rayO, rayPlaneYP);
    float dPYN = distance(rayO, rayPlaneYN);
    float dPC = distance(rayO, rayPlaneCeil);
    float dLi = distance(rayO, rayLight.xyz);
    float dGSph = distance(rayO, glassP);

    //minD = min(dSph, min(dPF, min(dPXP, min(dPXN, min(dPYP, min(dPYN, min(dPC, min(dLi, dGSph))))))));
    //this one doesn't include xn and yn
    minD = min(dSph, min(dPF, min(dPXP, min(dPYP, min(dPC, min(dLi, dGSph))))));
    //minD = min(dSph, min(dPF, dLi));

    //make sure that if nothing is hit, then no min dist passes the differential check
    if (minD > 50.){
        
        minD = -1.;

    }

    vec4 addCol = vec4(0.);

    float diffuseReflectance = .1;

    if(abs(minD - dSph) < 0.05){
        
        
        
        vec3 normal = normalize(rayPoint.xyz - sphereLoc);
        normal = DiffuseMaterialBounce(normal, rayD);

        newRayD = normalize(rayD - (2. * dot(rayD, normal) * normal));
        newRayO = rayPoint.xyz + .001 * newRayD;
        newNormal = normal;

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        //this is a reflective surface so not very attenuated
        //attenuation *= 2.;

        addCol = diffuseReflectance * vec4(.5) * attenuation;//vec4(dot(normalize(rayPoint.xyz), -lightD));

    }

    else if(abs(minD - dPF) < 0.05){
        
        
        
        newRayD = DiffuseMaterialBounce(vec3(0., 0., 1.), rayD);
        newRayO = rayPlaneFloor + newRayD * .001;
        newNormal = vec3(0., 0., 1.);

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(1., 0., 0., .8) * attenuation;

    }

    else if(abs(minD - dPXP) < 0.05){
        
        
        
        newRayD = DiffuseMaterialBounce(vec3(-1., 0., 0.), rayD);
        newRayO = rayPlaneXP + newRayD * .001;
        newNormal = vec3(-1., 0., 0.);

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(1.) * attenuation;

    }
    else if(abs(minD - dPXN) < 0.05){
        
        

        newRayD = DiffuseMaterialBounce(vec3(1., 0., 0.), rayD);
        newRayO = rayPlaneXN + newRayD * .001;
        newNormal = vec3(1., 0., 0.);

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(.8) * attenuation;

    }
    else if(abs(minD - dPYP) < 0.05){
        
        

        newRayD = DiffuseMaterialBounce(vec3(0., -1., 0.), rayD);
        newRayO = rayPlaneYP + newRayD * .001;
        newNormal = vec3(0., -1., 0.);
        
        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(.8) * attenuation;

    }
    else if(abs(minD - dPYN) < 0.05){
        
        

        newRayD = DiffuseMaterialBounce(vec3(0., 1., 0.), rayD);
        newRayO = rayPlaneYN + newRayD * .001;
        newNormal = vec3(0., 1., 0.);

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(0., 0., 1., .8) * attenuation;
        
    }
    else if(abs(minD - dPC) < 0.05){
        
        

        newRayD = DiffuseMaterialBounce(vec3(0., 0., -1.), rayD);
        newRayO = rayPlaneCeil + newRayD * .001;
        newNormal = vec3(0., 0., -1.);

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        addCol = diffuseReflectance * vec4(0., 0., 1., 1.) * attenuation;

        
    }
    else if(abs(minD - dLi) < 0.05){
        
        //no attenuation here because this is the light source
        addCol = vec4(2.5);

        vec3 normal = normalize(rayLight.xyz - lightO);

        newRayD = DiffuseMaterialBounce(normal, rayD);
        newRayO = rayLight.xyz + newRayD * .001;
        newNormal = normal;


    }
    else if(abs(minD - dGSph) < 0.05){

        newRayD = mix(glassD, DiffuseMaterialBounce(glassN, glassD), .01);
        newRayO = glassP + newRayD * .001;
        newNormal = glassN;

        float attenuation = DiffuseAttenuation(newRayO, newNormal, lightO);

        //no attenuation here because it's glass and perfectly refracts
        addCol = vec4(.25) * attenuation;//vec4(diffuseReflectance) * .25;


    }

    
    newCol = addCol;



    mat4 outData = mat4(
    vec4(newRayD, 0.),
    vec4(newRayO, 0.),
    vec4(newNormal, 0.),
    newCol
    );

    return outData;
}









void DeleteRandomVertex(inout vec3[maxPath] Proposal, inout vec4[maxPath] ProposalRadiance, inout int ProposalLength, out int RemVertIndex, vec2 seed){
    
    int rint = int(hash3(seed) * float(ProposalLength));
    rint = min(rint, ProposalLength - 1);
    
    RemVertIndex = rint;
    
    for(int i = rint; i < ProposalLength - 1; i++){
        Proposal[i] = Proposal[i + 1];
        ProposalRadiance[i] = ProposalRadiance[i + 1];
    }
    
    
    //no matter what the former last index should become an invalid point
    Proposal[ProposalLength - 1] = vec3(1000.);
    ProposalRadiance[ProposalLength - 1] = vec4(1000.);
    
    
    
    ProposalLength--;
    
}

void InsertRandomVertex(inout vec3[maxPath] Proposal, inout vec4[maxPath] ProposalRadiance, inout int ProposalLength, out int NewVertIndex, vec3 lightO, vec3 camC, vec2 seed){
    
    //in theory rint should be of 0 to 2 less than the number of vertices
    // in a path. However, I don't include either the camera or the light source
    // in the path list, but the segments connecting the light source and the last
    // bounce is a valid segment. Therefore the valid segment count is actually
    // pathlength. With one bounce, there is one segment.
    int rint = int(hash3(seed) * float(ProposalLength));
    
    NewVertIndex = rint + 1;
    
    //with all the above said, when I pick a random int (rint), this
    // value should be 0 for the first segment, and n - 1 for the last segment of a 
    // path of length n vertices, and n segments.
    rint = min(rint, ProposalLength - 1);
    
    
    
    mat4 segmentStartVertexData;
    //if the chosen segment is the first one, retrace from camera to first bounce
    if(rint == 0){
        segmentStartVertexData = RayCast(normalize(Proposal[rint] - camC), camC, lightO);
    }
    //if the chosen segment is a middle segment, retrace a ray from vertex before to segment start
    else{
        segmentStartVertexData = RayCast(normalize(Proposal[rint] - Proposal[rint - 1]), camC, lightO);
    }
    
    mat4 newVertex = RayCast(segmentStartVertexData[0].xyz, segmentStartVertexData[1].xyz, lightO);
    
    
    
    for(int i = ProposalLength; i > rint; i--){
        
        Proposal[i] = Proposal[i - 1];
        ProposalRadiance[i] = ProposalRadiance[i - 1];
        
    }
    
    Proposal[rint + 1] = newVertex[1].xyz;
    ProposalRadiance[rint + 1] = newVertex[3];
    
    ProposalLength++;
    
}

float DeletionTransitionPDF(int ProposalLength){
    
    return 1. / float(ProposalLength + 1);
    
}

float InsertionTransitionPDF(vec3[maxPath] ProposalPath, int ProposalPathLength, int NewVertIndex){
    
    float probability = 1. / float(ProposalPathLength - 1);
    
    vec3 dv = normalize(ProposalPath[NewVertIndex] - ProposalPath[NewVertIndex - 1]);
    
    //lightO has no bearing on this normal retrieval so pass vec3(0.) for it
    vec3 prevVertNormal = RayCast(-dv, ProposalPath[NewVertIndex - 1] + (dv * .1), vec3(0.))[2].xyz;
    
    float directionalPDF = max(0., dot(dv, prevVertNormal) / pi);
    
    return probability * directionalPDF;
    
}

vec4 EvaluatePathColor(vec3[maxPath] Path, vec4[maxPath] PathRadiance, int PathLength, vec3 camC, vec3 lightO){
    vec4 color = vec4(1.);

    mat4 rayResult = RayCast(normalize(Path[0] - camC), camC, lightO);

    vec4 newColor = rayResult[3];

    color = newColor;


    for(int i = 1; i < PathLength; i++){

        color *= PathRadiance[i];
    }


    rayResult = RayCast(normalize(lightO - Path[PathLength - 1]), Path[PathLength - 1], lightO);
    
    color *= rayResult[3];

    
    
    return color;
}

float EvaluatePathLuminosity(vec3[maxPath] Path, vec4[maxPath] PathRadiance, int PathLength, vec3 camC, vec3 lightO){
    
    
    float totalLuminosity = 0.;
    
    for(int i = 0; i < PathLength; i++){
        totalLuminosity += dot(PathRadiance[i].rgb, vec3(0.2126, .7152, 0.0722));
    }
    
    return totalLuminosity;
    
    /*
    vec4 color = EvaluatePathColor(Path, PathRadiance, PathLength, camC, lightO);

    return dot(color.rgb, vec3(0.2126, .7152, 0.0722));
    */
}




//NOTE: these two functions are completely symmetric if you pass path = proposal for one or the other
// note that DeletedVertIndex must be the index of the original vertex in the base path that was deleted
float DeletionAcceptance(vec3[maxPath] Path, vec4[maxPath] PathRadiance, int PathLength, vec3[maxPath] Proposal, vec4[maxPath] ProposalRadiance, int ProposalLength, vec3 camC, vec3 lightO, int DeletedVertIndex){
    
    float PathLuminosity = EvaluatePathLuminosity(Path, PathRadiance, PathLength, camC, lightO);
    
    float ProposalLuminosity = EvaluatePathLuminosity(Proposal, ProposalRadiance, ProposalLength, camC, lightO);
    
    
    if(PathLuminosity <= 0. || ProposalLuminosity <= 0.){
        return 0.;
    }
    
    float LuminosityRatio = ProposalLuminosity / PathLuminosity;
    
    float ProposalTransition = DeletionTransitionPDF(ProposalLength);
    
    float PathTransition = InsertionTransitionPDF(Path, PathLength, DeletedVertIndex);
    
    return min(1., LuminosityRatio * (ProposalTransition / PathTransition));

}

// note that InsertedVertIndex must be the index of the new vertex in the new proposal path
float InsertionAcceptance(vec3[maxPath] Path, vec4[maxPath] PathRadiance, int PathLength, vec3[maxPath] Proposal, vec4[maxPath] ProposalRadiance, int ProposalLength, vec3 camC, vec3 lightO, int InsertedVertIndex){
    
    float PathLuminosity = EvaluatePathLuminosity(Path, PathRadiance, PathLength, camC, lightO);
    
    float ProposalLuminosity = EvaluatePathLuminosity(Proposal, ProposalRadiance, ProposalLength, camC, lightO);
    
    if(PathLuminosity <= 0.1 || ProposalLuminosity <= 0.1){
        return 0.;
    }
    
    float LuminosityRatio = ProposalLuminosity / PathLuminosity;
    
    float ProposalTransition = InsertionTransitionPDF(Proposal, ProposalLength, InsertedVertIndex);
    
    float PathTransition = DeletionTransitionPDF(PathLength);
    
    return min(1., LuminosityRatio * (ProposalTransition / PathTransition));
    
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
    

    vec3 lightO = vec3(-2., -.1, .0);
    vec3 lightDir = normalize(-lightO);
    float lightR = .2;
    
    








    
    int pathMutationIndex = 0;
    int pathLength = 0;
    vec3 path[maxPath] = vec3[](
    vec3(1000.), vec3(1000.), vec3(1000.), vec3(1000.),
    vec3(1000.), vec3(1000.), vec3(1000.), vec3(1000.));
    vec4 pathRadiance[maxPath] = vec4[](
    vec4(1000.), vec4(1000.), vec4(1000.), vec4(1000.),
    vec4(1000.), vec4(1000.), vec4(1000.), vec4(1000.));

    
    mat4 rayResult = RayCast(rayD, camC, lightO);
    path[0] = rayResult[1].xyz;
    pathRadiance[0] = rayResult[3];
    

    
    rayResult = RayCast(rayResult[0].xyz, rayResult[1].xyz, lightO);
    path[1] = rayResult[1].xyz;
    pathRadiance[1] = rayResult[3];
    
    pathLength = 2;

    
    if(distance(path[0].xyz, camC) < .01){
        imageStore(imgOutput, texelCoord, vec4(0.));
        return;
    }
    
    int tentativePathLength = 0;
    vec3 tentativePath[maxPath];
    vec4 tentativePathRadiance[maxPath];
    
    
    int mutationIndex = -1;
    float acceptanceProbability = 0.;
    float xi3 = 1.;

    vec4 totalColor = vec4(0.);
    
    
    int acceptances = 0;
    
    for(int i = 0; i < N; i++){
        
        vec2 iterSeed = fragCoord.xy + vec2(i * 17.37, float(frame) * 193.67);
        
        bool deleteOrInsert = Chance(.5, iterSeed);
        
        //whew, apparaently glsl doesnt use pointers like c++ so this is okay actually
        tentativePath = path;
        tentativePathRadiance = pathRadiance;
        tentativePathLength = pathLength;
        
        
        if(deleteOrInsert && pathLength > 1){
            
            DeleteRandomVertex(tentativePath, tentativePathRadiance, tentativePathLength, mutationIndex, iterSeed * uv.yx);
            
            acceptanceProbability = DeletionAcceptance(path, pathRadiance, pathLength, 
            tentativePath, tentativePathRadiance, tentativePathLength,
            camC, lightO, mutationIndex);
            
        }
        else if(pathLength < maxPath){

            InsertRandomVertex(tentativePath, tentativePathRadiance, tentativePathLength, mutationIndex, lightO, camC, iterSeed * uv.yx);
            
            acceptanceProbability = InsertionAcceptance(path, pathRadiance, pathLength, 
            tentativePath, tentativePathRadiance, tentativePathLength, 
            camC, lightO, mutationIndex);
            
        }
        
        
        // xi3 (pronounced kai or kye, greek letter) from Metropolis's original paper
        xi3 = hash3(iterSeed * fragCoord);
        
        if(xi3 < acceptanceProbability){
            path = tentativePath;
            pathRadiance = tentativePathRadiance;
            pathLength = tentativePathLength;

            acceptances++;
        }
        
        
        
        
        totalColor += log(min(EvaluatePathColor(path, pathRadiance, pathLength, camC, lightO), .8) + 1.);
        
    }
    
    
    
    totalColor /= float(N);
    
    col += totalColor / pow(float(frame + 1), 1.);

    
    //col = mix(imageLoad(imgOutput, texelCoord), vec4(float(acceptances) / float(N)), .1);

    imageStore(imgOutput, texelCoord, col);
}
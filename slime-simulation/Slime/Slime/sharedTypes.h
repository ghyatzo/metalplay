//
//  sharedTypes.h
//  Slime
//
//  Created by Camillo Schenone on 19/04/21.
//

#ifndef sharedTypes_h
#define sharedTypes_h

#include <simd/simd.h>


#define _NumAgents 1000000
#define _fps 60
#define _WIDTH 2460
#define _HEIGHT 1444

typedef struct {
    vector_float2 position;
    vector_float2 texturePosition;
} CVertex;

typedef struct {
    vector_float2 position;
    float angle;
} Agent;

typedef struct {
    float velocity;
    float dt;
    float evaporateSpeed;
    float diffuseSpeed;
    float turnSpeed;
    
    float sensorAngleOffset;
    float sensorOffsetDst;
    float sensorSize;
}  Options;


uint hash(uint state) {
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    
    return state;
}

#endif /* sharedTypes_h */

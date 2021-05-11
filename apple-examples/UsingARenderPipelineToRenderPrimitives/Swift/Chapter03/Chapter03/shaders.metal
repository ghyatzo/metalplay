//
//  shaders.metal
//  Chapter03
//
//  Created by Camillo Schenone on 16/04/21.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// include the header shared between the Metal Shader file and Swift logic program.
#include "shaderTypes.h"

typedef struct {
    vector_float2 position;
    vector_float4 color;
} CVertex;

// The vertex stage generates data for a vertex so it need to provide a color and a transformed positon.
// By declaring a custom struct we can pass the data that we want through to the resterizer (and indirectly to the fragment shader)
// Metal must know what member is the position in the rasterizer data.

struct ResterizerData {
    // The [[ position ]] attribute of this member indicates that this value is the _CLIP SPACE_ position of the vertex when this structure is
    // returned from the vertex function. That is, we tell the GPU that the position here is the transformed position.
    vector_float4 position [[ position ]];
    
    // Since this member does not have a special attribute, the
    // resterizer interpolates its value with the values of the other
    // triangle vertices and then passes the interpolated value to the
    // fragment shader for each fragment in the triangle.
    vector_float4 color;
};


// Define the shaders
vertex ResterizerData
vertexShader(uint vid [[ vertex_id ]],
             device const CVertex *vertices [[ buffer(InputDataVertices) ]],
             device const vector_float2 *viewportSizePointer  [[ buffer(InputDataViewportSize) ]])
{
    // The viewportsize are the width and height of the view
    // that are needed to
    // transform the input coordinates into the clip space coordinates.
    vector_float2 pixelSpacePosition = vertices[vid].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);

    ResterizerData out;
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    out.color = vertices[vid].color;

    return out;
}

fragment float4 fragmentShader(ResterizerData in [[ stage_in ]]) {
    // If the fragment function writes to multiple render targets,
    // it must declare a struct with fields for each render target.
    // In this case we only have one.
    
    return in.color;
}

    




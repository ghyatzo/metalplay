//
//  shaders.metal
//  objc-metal
//
//  Created by Camillo Schenone on 14/04/21.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 vertexShader(device float4 *vertices [[ buffer(0) ]], uint vid [[ vertex_id ]] ) {
    return vertices[vid];
}

fragment float4 fragmentShader(float4 input [[stage_in]] ) {
    
    // set color to red
    return float4(1.0,0.0,0.0,1.0);
}

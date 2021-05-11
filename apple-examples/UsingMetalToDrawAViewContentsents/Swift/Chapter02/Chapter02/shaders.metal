
#include <metal_stdlib>
using namespace metal;

// We want to represent the same exact model that was defined in the CPU side of things

struct VertexIn {
    float3 position;
    float4 color;
};

// We want to pass informations through the resteriser!
struct RasterizerData{
    // by setting up the "position" attribute we tell the rasterizer not to touch it and not to interpolate it.
    float4 position [[ position ]];
    float4 color;
};

vertex RasterizerData
vertex_shader(device const VertexIn *vertices [[ buffer(0) ]],
                            uint vid [[ vertex_id ]]){
    RasterizerData rd;
    
    rd.position = float4(vertices[vid].position, 1);
    rd.color = vertices[vid].color;
    
    return rd;
}



fragment half4 fragment_shader(RasterizerData rd [[ stage_in ]]){
    
    float4 color = rd.color;
    return half4(color.r, color.g, color.b, color.a);
}

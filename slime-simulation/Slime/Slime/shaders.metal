#include <metal_stdlib>
using namespace metal;

#include "sharedTypes.h"

struct ResterizerData {
    vector_float4 position [[ position ]];
    vector_float2 texturePosition;
};

// Define the shaders
//vertex ResterizerData
//vertexShader(uint vid [[ vertex_id ]],
//             device const CVertex *vertices [[ buffer(0) ]],
//             device const vector_float2 *viewportSizePointer  [[ buffer(1) ]])
//{
//
//    vector_float2 pixelSpacePosition = vertices[vid].position.xy;
//    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
//
//    ResterizerData out;
//    out.position = vector_float4(0.0, 0.0, 1.0, 1.0);
//    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
//
//    out.texturePosition = vertices[vid].texturePosition;
//
//    return out;
//}
vertex ResterizerData
vertexShader(uint vid [[ vertex_id ]],
             device const CVertex *vertices [[ buffer(0) ]])
{

    ResterizerData out;
    out.position = vector_float4(vertices[vid].position, 0.0, 1.0);
    out.texturePosition = vertices[vid].texturePosition;

    return out;
}

fragment float4
fragmentShader(ResterizerData in [[ stage_in ]],
               texture2d<float, access::sample> colorTexture [[ texture(1) ]]) {
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
//    constexpr sampler textureSampler (mag_filter::nearest, min_filter::nearest);
    
    return colorTexture.sample(textureSampler, in.texturePosition);
}


kernel void
updateTexture(texture2d<float, access::read> inTexture [[ texture(0) ]],
              texture2d<float, access::write> outTexture [[ texture(1) ]],
              constant Options *options [[ buffer(2) ]],
              uint2 id [[ thread_position_in_grid ]])
{
    if((id.x > _WIDTH) || (id.y > _HEIGHT))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    // diffuse
    // evaporate
    int size = 1;
    float4 originalValue = inTexture.read(id).rgba;
    float4 cumulatedValue = 0;
    for (int i = -size; i <= size; i++)
    {
        for (int j = -size; j <= size; j++)
        {
            int sx = id.x + i;
            int sy = id.y + j;

            cumulatedValue += inTexture.read(uint2(sx, sy));
        }
    }
    float4 blurred = cumulatedValue / 9.0;
    float4 diffused = originalValue + (blurred - originalValue) * clamp(options->diffuseSpeed * options->dt, 0.0, 1.0);
    float4 evaporatedValue = max(0, diffused - options->evaporateSpeed * options->dt);

    outTexture.write(evaporatedValue, id);
    // test randomness
//    float value = hash(id.y * _WIDTH + id.x);
//    outTexture.write(value / (float) UINT_MAX, id);
}

kernel void
updateAgents(device Agent *agents [[ buffer(1) ]],
             constant Options *options [[ buffer(2) ]],
             texture2d<float, access::read> textureIn [[ texture(0) ]],
             texture2d<float, access::write> texture [[ texture(1) ]],
             uint id [[ thread_position_in_grid ]])
{
    if (id >= _NumAgents) return;
    
    Agent agent = agents[id];
    uint random = hash((uint)(agent.position.y * (float)_WIDTH + agent.position.x) + hash(id));

    float weights [3];
    for (int w = -1; w <= 1; w++) {
        float sensorAngle = agent.angle + options->sensorAngleOffset * w;
        float2 sensorDir  = float2(cos(sensorAngle), sin(sensorAngle));
        int2 sensorCenter = (int2)(agent.position + sensorDir * options->sensorOffsetDst);
        float sum = 0;

        int sensorsize = options->sensorSize;
        for (int i = -sensorsize; i <= sensorsize; i++) {
            for (int j = -sensorsize; j <= sensorsize; j++) {
                uint2 pos = (uint2)sensorCenter + uint2(i, j);

                sum += textureIn.read(pos).a;
            }
        }
        weights[1+w] = sum;
    }

    // sense
    float weightLeft = weights[0];
    float weightForward = weights[1];
    float weightRight = weights[2];

    float randomSteerStrenght = (float)random / (float)UINT_MAX;

    if (weightForward > weightLeft && weightForward > weightRight){
        agents[id].angle += 0;
    }
    else if (weightForward < weightLeft && weightForward  < weightRight) {
        agents[id].angle += (randomSteerStrenght - 0.5) * 2.0 * options->turnSpeed * options->dt;
    }
    else if (weightRight > weightLeft) {
        agents[id].angle -= randomSteerStrenght * options->turnSpeed * options->dt;
    }
//    else if (weightRight > weightLeft) {
//        agents[id].angle -= options->turnSpeed * options->dt;
//    }
    else if (weightLeft > weightRight) {
        agents[id].angle += randomSteerStrenght * options->turnSpeed * options->dt;
    }
//    else if (weightLeft > weightRight) {
//        agents[id].angle += options->turnSpeed * options->dt;
//    }

    float2 direction = float2(cos(agents[id].angle), sin(agents[id].angle));
    float2 newpos = agents[id].position + direction * options->velocity * options->dt;

    if (newpos.x <= 0 || newpos.x >= _WIDTH || newpos.y <= 0 || newpos.y >= _HEIGHT) {
        newpos = clamp(newpos, float2(1,1), float2(_WIDTH-1, _HEIGHT-1));
        agents[id].angle = ((float)random / (float)UINT_MAX) * 2 * M_PI_F;
    }

    agents[id].position = newpos;
    texture.write(float4(1), uint2(newpos));
}


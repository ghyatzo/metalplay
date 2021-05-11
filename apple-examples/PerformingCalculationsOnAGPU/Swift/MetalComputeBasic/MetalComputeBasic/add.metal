//
//  add.metal
//  MetalComputeBasic
//
//  Created by Camillo Schenone on 14/04/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* result,
                       uint index [[thread_position_in_grid]])
{
    result[index] = inA[index] + inB[index];
}

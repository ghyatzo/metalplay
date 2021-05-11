//
//  main.swift
//  MetalComputeBasic
//
//  Created by Camillo Schenone on 14/04/21.
//

import Foundation
import Metal

public func classic_add_array(inA: [Float], inB: [Float], result: inout [Float], length: Int) {
    for i in 0..<length {
        result[i] = inA[i] + inB[i]
    }
}

class MetalAdder: NSObject {
    var device:MTLDevice
    var addArrayPipelineState:MTLComputePipelineState!
    var commandQueue:MTLCommandQueue!
    
    // Initialize random buffers
    var mBufferA:MTLBuffer?
    var mBufferB:MTLBuffer?
    var mBufferResult:MTLBuffer?
    
    var arrayLength:Int
    
    init(device: MTLDevice, length: Int) {
        // Init the class with the device
        self.device = device
        self.arrayLength = length
        self.commandQueue = device.makeCommandQueue()
        
        super.init()
        
        createComputePipelineState()
    }
    
    func createComputePipelineState() {
        print("creating pipeline")
        // import the .metal shader file contents into a default Library
        let library = device.makeDefaultLibrary()
        let addFunction = library?.makeFunction(name: "add_arrays")
        
        do {
            addArrayPipelineState = try device.makeComputePipelineState(function: addFunction!)
        } catch let error {
            print(error)
        }
        
        
    }
    
    func sendComputeCommand() {
        print("sending command")
        let commandBuffer = commandQueue!.makeCommandBuffer()
        
        let commandEncoder = commandBuffer!.makeComputeCommandEncoder()
        
        self.encodeCommand(commandEncoder)
        
        commandEncoder!.endEncoding()
        commandBuffer!.commit()
        commandBuffer!.waitUntilCompleted()
        
    }
    
    func encodeCommand(_ commandEncoder: MTLComputeCommandEncoder?) {
        print("\t creating pipeline and encoder")
        // activate the right pipeline
        commandEncoder?.setComputePipelineState(addArrayPipelineState!)
        commandEncoder?.setBuffers([mBufferA, mBufferB, mBufferResult], offsets: [0, 0, 0], range: 0..<3)
        
        let gridSize = MTLSizeMake(self.arrayLength, 1, 1)
        var threadGroupSize = addArrayPipelineState?.maxTotalThreadsPerThreadgroup
        threadGroupSize = (threadGroupSize! > self.arrayLength) ? self.arrayLength : threadGroupSize
        
        commandEncoder?.dispatchThreads(gridSize,
                                        threadsPerThreadgroup: MTLSizeMake(threadGroupSize!, 1, 1))
    }
    
    func prepareData() {
        
        let randomData = randomFloatData(self.arrayLength)
        
        self.mBufferA = self.device.makeBuffer(bytes: randomData , length: self.arrayLength * MemoryLayout<Float>.size, options: MTLResourceOptions.storageModeShared)
        self.mBufferB = self.device.makeBuffer(bytes: randomData , length: self.arrayLength * MemoryLayout<Float>.size, options: MTLResourceOptions.storageModeShared)
        self.mBufferResult = self.device.makeBuffer(bytes: randomData , length: self.arrayLength * MemoryLayout<Float>.size, options: MTLResourceOptions.storageModeShared)
    }
    
    func randomFloatData(_ length: Int) -> [Float] {
        var arr = [Float](repeating: 0, count: self.arrayLength)
        
        for i in 0..<self.arrayLength {
            arr[i] = Float.random(in: 0...1)
        }
        
        return arr
    }
}



func main() {
    let device = MTLCreateSystemDefaultDevice()!
    
    let addition = MetalAdder(device: device, length: 1000)
    
    addition.prepareData()
    
    addition.sendComputeCommand()
    
    print("done")
    
}




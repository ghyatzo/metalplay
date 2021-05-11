//: A Cocoa based Playground to present user interface

import MetalKit
import PlaygroundSupport

// Abstract the GPU
guard let device = MTLCreateSystemDefaultDevice() else {
  fatalError("GPU is not supported")
}

// Create a Command Queue
let commandQueue = device.makeCommandQueue()

// Set up the metal layer that creates a "Drawable" texture to paint on.
let metalLayer = CAMetalLayer()
metalLayer.device = device
metalLayer.pixelFormat = .bgra8Unorm
let drawable = metalLayer.nextDrawable()!

// Configure a Render Pass via _descriptor_
// This is when we describe the properties of _how_ to render the frame
// that we will then pass to a command buffer through the command encoder that will
// translate it for us.
let passDescriptor = MTLRenderPassDescriptor()
passDescriptor.colorAttachments[0].texture = drawable.texture
passDescriptor.colorAttachments[0].loadAction = .clear
passDescriptor.colorAttachments[0].storeAction = .store
passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.8, 0.0, 0.0, 1.0)

let commandBuffer = commandQueue?.makeCommandBuffer()
let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)!

// Create a view
let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
let view = MTKView(frame: frame, device: device)

// Present the view in Playground
PlaygroundPage.current.liveView = view


import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    
    typealias NSViewType = MTKView
        
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.colorPixelFormat = context.coordinator.viewPixelFormat
        
        mtkView.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0)
        mtkView.enableSetNeedsDisplay = false
        
        mtkView.preferredFramesPerSecond = 120
        return mtkView    
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        
        var parent: MetalView
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        
        var viewPixelFormat: MTLPixelFormat!
        var viewPort: MTLViewport!
        
        var library: MTLLibrary!
        var renderPipelineState: MTLRenderPipelineState!
        
        struct CVertex {
            var position: vector_float2
            var color: vector_float4
        }
        
        // We will showcase the role of transforms usually made inside the vertex shader.
        // input coordinates are defined in a custom coordinate space, that 'pixels from the center of the view'
        let vertexArray: [CVertex] = [
            CVertex(position: vector2(0, 250), color: vector4(1, 0, 0, 1)),
            CVertex(position: vector2(-250, -250), color: vector4(0, 1, 0, 1)),
            CVertex(position: vector2(250, -250), color: vector4(0, 0, 1, 1))
        ]
        
        init(_ parent: MetalView) {
            self.parent = parent
            
            if let device = MTLCreateSystemDefaultDevice() {
                self.device = device
            }
            self.commandQueue = device.makeCommandQueue()
            self.viewPixelFormat = .bgra8Unorm // Default
            self.viewPort = MTLViewport()
            
            self.library = device.makeDefaultLibrary()
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = "basic pipeline"
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = viewPixelFormat
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch let error as NSError {
                print(error)
            }
            
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewPort.width = Double(size.width)
            viewPort.height = Double(size.height)
        }

        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            // set the viewport so that metal knows which part of the render target you want to draw into.
            renderEncoder?.setViewport(viewPort)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            //When working with little amounts of data we can pass the data directly to the command buffer without setting up a MTLBuffer
            renderEncoder?.setVertexBytes(vertexArray,
                                          length: vertexArray.count*MemoryLayout<CVertex>.stride,
                                          index: Int(InputDataVertices.rawValue))
        
            var _viewPort: vector_float2 = vector2(Float(viewPort.width), Float(viewPort.height))
            withUnsafePointer(to: &_viewPort) { pointer in
                renderEncoder?.setVertexBytes(pointer,
                                              length: MemoryLayout<simd_double2>.size,
                                              index: Int(InputDataViewportSize.rawValue))
            }
            
            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexArray.count)
            
            renderEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
        

    }

}

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    
    func makeCoordinator() -> Coordinator {
        NSLog("makeCoordinator()")
        return Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        NSLog("makeNSView()")
        // Here an almost complete initialisation of a MTKView
        let mtkView = MTKView()
        
        // required
        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.metalDevice
        
        // Color Render Target
        mtkView.colorPixelFormat = context.coordinator.viewPixelFormat
        mtkView.framebufferOnly = false // true: optimized drawable but cannot sample/read/write - false: opposite.
        mtkView.drawableSize = mtkView.frame.size // made explicit but it is the default
        mtkView.autoResizeDrawable = true // default: true
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        
        // Drawing Behaviour
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false // If false the view redraws the contents at a frame rate specified by the above
        mtkView.enableSetNeedsDisplay = true // The drawing and pausing become event based.

        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        print(nsView.frame.size)
        NSLog("updateNSView()")
        // DO NOTHING
    }
    
    // Our delegate and Renderer
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: MetalView
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        var viewPixelFormat: MTLPixelFormat!
        
        // hello triangle stuffs
        var renderPipelineState: MTLRenderPipelineState!
        var vertexBuffer: MTLBuffer!
        
        struct CustomVertex {
            var position: vector_float3
            var color: vector_float4
        }
        
        let vertexArray: [CustomVertex] = [
            CustomVertex(position: vector_float3(0, 0.5, 0), color: vector_float4(1, 1, 0, 1)),
            CustomVertex(position: vector_float3(-0.5, -0.5, 0), color: vector_float4(0, 1, 1, 1)),
            CustomVertex(position: vector_float3(0.5, -0.5, 0), color: vector_float4(1, 0, 1, 1))
        ]
        
        init(_ parent: MetalView) {
            NSLog("coordinator.init()")
            // Initialise here the values that are needed to initialize the Metal View
            self.parent = parent
        
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                self.metalDevice = metalDevice
            }
            self.metalCommandQueue = metalDevice.makeCommandQueue()!
            self.viewPixelFormat = .bgra8Unorm // default
            
            // set up library
            let library = metalDevice.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "vertex_shader")
            let fragmentFunction = library?.makeFunction(name: "fragment_shader")
            
            // set up A basic pipeline
            let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineStateDescriptor.label = "triangle pipeline"
            renderPipelineStateDescriptor.vertexFunction = vertexFunction
            renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
            renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = viewPixelFormat
            
            do {
                renderPipelineState = try metalDevice.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
            } catch let error as NSError {
                print(error)
            }
            
            super.init()
        }
        
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            NSLog("mtkView()")
            print(size)
            // DO NOTHING
        }
        func draw(in view: MTKView) {
//            NSLog("draw()")
            // Get a render Target, and a Pass descriptor (stuff like clear color, clear behaviour etc)
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            // create the data buffer
            vertexBuffer = metalDevice.makeBuffer(
                bytes: vertexArray, length: MemoryLayout<CustomVertex>.stride * vertexArray.count, options: [])
            // create command wrapper
            let commandBuffer = metalCommandQueue.makeCommandBuffer()
            // and an encode to translate our command
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            // choose the pipeline (What should the GPU do?)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            // Bind the data to the command (what data should the GPU work on?)
            renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            // Choose the primitive the vertices represent. (how should the GPU interpret the vertices?)
            // With this drawCall we are going to process _vertexArray.count_ number of vertices before passing
            // them to the rasterizer
            // We can choose different "groups" of vertices to render by modifying the starting position and specifying how many are there.
            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexArray.count)
            
            
            // All done, stop encoding commands
            renderEncoder?.endEncoding()
            // set up a callback to present() the drawable to the screen as soon as possible after it is done
            commandBuffer?.present(drawable)
            // Send the command buffer away to the command queue.
            commandBuffer?.commit()
        }
    }
}

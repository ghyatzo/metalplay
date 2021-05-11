import Cocoa
import AppKit
import MetalKit

// We need to instantiate a MTLKView subclass to override the draw() function and call it whenever we need
// Another method would be NOT to create a new subclass but instead to define a _Delegate_ which will call
// a renderer for us whenever the view will need refreshing.
class MView: MTKView {
    
    // A _vertex_ is not just a point in space, it holds many more properties
    // lets create a struct to incorporate all of these things
    struct CustomVertex {
        var position: vector_float3
        var color: vector_float4
    }
    
    let vertexArray: [CustomVertex] = [
        CustomVertex(position: vector_float3(0, 0.5, 0), color: vector_float4(1, 1, 0, 1)),
        CustomVertex(position: vector_float3(-0.5, -0.5, 0), color: vector_float4(0, 1, 1, 1)),
        CustomVertex(position: vector_float3(0.5, -0.5, 0), color: vector_float4(1, 0, 1, 1))
    ]
    
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    
    var vertexBuffer: MTLBuffer!
    
    required init(coder: NSCoder) {
        // Instantiating a subclass requires us to initialise it via the init(coder: ) initialiser
        super.init(coder: coder)
        
        // create a new device and set it.
        self.device = MTLCreateSystemDefaultDevice()

        // When the view creates a render pass, it sets the load action for the color render target to
        // MTLLoadAction.clear and uses this color as the clear color.
        // The default value is (0.0, 0.0, 0.0, 1.0).
        self.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0)
        // The pixel format must be one that the underlying CAMetalLayer can use. See pixelFormat.
        // The default value is MTLPixelFormat.bgra8Unorm.
        // The pixel format will need to match the output of our fragment shader.
        self.colorPixelFormat = .bgra8Unorm
        
        // Instantiate the command Queue
        self.commandQueue = device?.makeCommandQueue()
        
        // Generate a a PipelineState
        createRenderPipelineState()
        
    }
    
    init(frame: CGRect, device: MTLDevice) {
        super.init(frame: frame, device: device)
        self.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0)
        self.colorPixelFormat = .bgra8Unorm
        self.commandQueue = self.device?.makeCommandQueue()
        createRenderPipelineState()
    }
    
    func createRenderPipelineState() {
        // We need a library that manages the shaders.
        // The general gist is:
        // - Write down the source code for the shaders
        // - Tell the library to create a MTLFunction from the source code that we provided
        // - Plug that function into the PipelineState and create a graphical pipeline
        //           input -> vertex function -> rasterise -> fragment shader -> draw
        //   with our custom functions implemented inside.
        let library = device?.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertex_shader")
        let fragmentFunction = library?.makeFunction(name: "fragment_shader")
        
        // We wont build the actual pipeline ourselves but we will initialise a _Descriptor_ that
        // Will "describe" how the pipeline should be
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        do {
            renderPipelineState = try device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch let error as NSError {
            print(error)
        }
    }
    
    override func draw(_ rec: NSRect) {
        guard let drawable = self.currentDrawable else { return }
        guard let renderPassDescriptor = self.currentRenderPassDescriptor else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setRenderPipelineState(renderPipelineState)
        
        // This was the first iteration. Where we only specify the positions of a vertex.
//        // very slow, just for the sake of learning
//        let vertexArray = [simd_float3(0, 0.5, 0), simd_float3(-0.5, -0.5, 0), simd_float3(0.5, -0.5, 0)]
//        let vertexBuffer = device?.makeBuffer(bytes: vertexArray, length: vertexArray.count * MemoryLayout<simd_float3>.stride, options: .storageModeShared)
//
//        // What we do here is basically telling the command encoder what vertex buffers we are going to actually use (a kind of "BIND" in openGL)
//        // and then we are going to tell the GPU how to interpret these vertices? how to connect them together.
//        // That is, we have three points: Should it be a triangle or just two lines? that is the drawPrimitives call.
//        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexArray.count)
        
        vertexBuffer = device?.makeBuffer(bytes: vertexArray, length: MemoryLayout<CustomVertex>.stride * vertexArray.count, options: .storageModeShared)
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexArray.count)
        
        renderCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
}

let view = MView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), device: MTLCreateSystemDefaultDevice()!)

let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1080, height: 720),
                      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                      backing: .buffered,
                      defer: true)
window.titlebarAppearsTransparent = true
window.center()
window.contentView = view


window.makeKeyAndOrderFront(nil)
//let winController = NSWindowController(window: window)
//winController.showWindow(nil)

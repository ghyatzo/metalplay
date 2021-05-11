import MetalKit
import SwiftUI
import ImGui

struct MetalView: NSViewRepresentable {
    
    typealias NSViewType = MTKView

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mView = MTKView()
        
        mView.delegate = context.coordinator
        mView.device = context.coordinator.device
        mView.colorPixelFormat = context.coordinator.viewPixelFormat
        
        mView.clearColor = MTLClearColorMake(0, 0, 0, 1.0)
        mView.enableSetNeedsDisplay = false
        
        mView.preferredFramesPerSecond = 60
        
        return mView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // DO NOTHING
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var library: MTLLibrary!
        
        var renderPipelineState: MTLRenderPipelineState!
        var computeTexturePS: MTLComputePipelineState!
        var updateAgentsPS: MTLComputePipelineState!
        
        var viewPixelFormat: MTLPixelFormat!
        var viewPort: MTLViewport!
        
        let WIDTH: Int = Int(_WIDTH)
        let HEIGHT:Int = Int(_HEIGHT)
        var textureIn: MTLTexture?
        var textureOut: MTLTexture?
        var textureTmp: MTLTexture?
        
        // ImGUI
        // TODO
        
        let quadVertex: [CVertex] = [
            CVertex(position: vector2(-1, 1), texturePosition: vector2(0, 0)),
            CVertex(position: vector2(1, 1), texturePosition: vector2(1,0)),
            CVertex(position: vector2(-1, -1), texturePosition: vector2(0, 1)),
            
            CVertex(position: vector2(1, -1), texturePosition: vector2(1, 1)),
            CVertex(position: vector2(-1, -1), texturePosition: vector2(0, 1)),
            CVertex(position: vector2(1, 1), texturePosition: vector2(1, 0))
        ]
        
        let numberOfAgents: Int = Int(_NumAgents)
        var options: Options = Options(
            velocity: 60,
            dt: Float(1.0/60.0),
            evaporateSpeed: Float(0.8),
            diffuseSpeed: Float(0.5),
            turnSpeed: Float(4 * 2 * Float.pi),
            sensorAngleOffset: Float(50),
            sensorOffsetDst: Float(40),
            sensorSize: Float(1)
        )

        
        var agents: [Agent] = []
        var agentBuffer: MTLBuffer!
        
        var frameCounter: Int = 0
        init(_ parent: MetalView) {
            
            super.init()
            // view
            self.viewPixelFormat    = .bgra8Unorm
            self.viewPort           = MTLViewport()
            //device and command chain
            if let device = MTLCreateSystemDefaultDevice() {
                self.device = device
            }
            self.commandQueue       = device.makeCommandQueue()!
            self.library            = device.makeDefaultLibrary()!

            makeRenderPipelineState()
            makeComputePipelineStates()
            createTextures()
            initAgentsCircle()
            
        }
        
        func makeRenderPipelineState() {
            let vertexFunction      = library.makeFunction(name: "vertexShader")
            let fragmentFunction    = library.makeFunction(name: "fragmentShader")
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = "render pipeline"
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = viewPixelFormat
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch let error as NSError { print(error) }
        }
        
        func makeComputePipelineStates() {
            let updateTexture = library.makeFunction(name: "updateTexture")
            let updateAgents  = library.makeFunction(name: "updateAgents")
            
            do {
                computeTexturePS = try device.makeComputePipelineState(function: updateTexture!)
                updateAgentsPS   = try device.makeComputePipelineState(function: updateAgents!)
            } catch let error as NSError { print(error) }
        }
        
        func createTextures() {
            let textureDescriptor   = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: viewPixelFormat, width: WIDTH, height: HEIGHT, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            self.textureIn  = device.makeTexture(descriptor: textureDescriptor)
            self.textureOut = device.makeTexture(descriptor: textureDescriptor)
        }
        
        func initAgentsCircle(){
            agents.reserveCapacity(numberOfAgents)
            
            let r = 0
            let R = _HEIGHT/4
            let center = vector2(0.5 * Float(WIDTH), 0.5 * Float(HEIGHT))
            
            for _ in 0..<numberOfAgents {
                let theta = Float.random(in: 0..<2*Float.pi)
                let position = Float(Int.random(in: r...Int(R))) * vector2(cos(theta), sin(theta)) + center
                
                agents.append(Agent(position: position, angle: Float.random(in: 0...1) * 2 * Float.pi))
//                agents.append(Agent(position: position, angle: theta + Float.pi))
            }
            
            self.agentBuffer = device.makeBuffer(bytes: agents,
                                                 length: MemoryLayout<Agent>.stride * agents.count,
                                                 options: .storageModeShared)
        }
        func initAgentsGrid(){
            agents.reserveCapacity(numberOfAgents)
            
            let numLinesW = 20
            let numLinesH = 20
            
            let stepW = WIDTH/numLinesW
            let stepH = HEIGHT/numLinesH

            
            for _ in 0..<numberOfAgents {
                let x = Int.random(in: 1...numLinesW-1) * stepW
                let y = Int.random(in: 1...numLinesH-1) * stepH
                let position = vector2(Float(x), Float(y))
                
                
                agents.append(Agent(position: position, angle: Float(Int.random(in: 0...1)) * 1.0/1.0 * Float.pi))
            }
            
            self.agentBuffer = device.makeBuffer(bytes: agents,
                                                 length: MemoryLayout<Agent>.stride * agents.count,
                                                 options: .storageModeShared)
        }
        
        func initAgentsUniform(){
            agents.reserveCapacity(numberOfAgents)
            
            for _ in 0..<numberOfAgents {
                let position = vector2(Int.random(in: 0...WIDTH), Int.random(in: 0...HEIGHT))
                
                agents.append(Agent(position: vector2(Float(position.x), Float(position.y)), angle: Float.random(in: 0...1) * 2 * Float.pi))
            }
            
            self.agentBuffer = device.makeBuffer(bytes: agents,
                                                 length: MemoryLayout<Agent>.stride * agents.count,
                                                 options: .storageModeShared)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewPort.width = Double(size.width)
            viewPort.height = Double(size.height)
        }
        
        func draw(in view: MTKView) {
            // imGui
            //  TODO
            
            // GPU COMMANDS
            let commandBuffer = commandQueue.makeCommandBuffer()
    
            // copy the old texture as the starting point for the next iteration.
            let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
            blitEncoder?.copy(from: textureOut!, to: textureIn!)
            blitEncoder?.endEncoding()
            // Set up the compute command and load data into the buffers
            let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
            computeEncoder?.setTexture(textureIn, index: 0)
            computeEncoder?.setTexture(textureOut, index: 1)
            computeEncoder?.setBuffer(agentBuffer, offset: 0, index: 1)
            withUnsafePointer(to: &options) { pointer in computeEncoder?.setBytes(pointer, length: MemoryLayout<Options>.stride, index: 2)}
            // First Pass: update the texture with evaporation and diffusion
            var pipeline = computeTexturePS!
            var _width = pipeline.threadExecutionWidth
            let _height = pipeline.maxTotalThreadsPerThreadgroup / _width
            var threadsPerGroup = MTLSize(width: _width, height: _height, depth: 1)
            let w = (WIDTH + threadsPerGroup.width - 1)/threadsPerGroup.width
            let h = (HEIGHT + threadsPerGroup.height - 1)/threadsPerGroup.height
            var threadsGroupsPerGrid = MTLSize(width: w, height: h, depth: 1)
            computeEncoder?.setComputePipelineState(pipeline)
            computeEncoder?.dispatchThreadgroups(threadsGroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            // Second Pass: update the agents positions
            pipeline = updateAgentsPS!
            _width  = pipeline.threadExecutionWidth
            threadsPerGroup = MTLSize(width: _width, height: 1, depth: 1)
            threadsGroupsPerGrid = MTLSize(width: (numberOfAgents + threadsPerGroup.width - 1)/threadsPerGroup.width, height: 1, depth: 1)
            computeEncoder?.setComputePipelineState(pipeline)
            computeEncoder?.dispatchThreadgroups(threadsGroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            computeEncoder?.endEncoding()

            // Start the rendering pass.
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder?.setViewport(viewPort)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexBytes(quadVertex, length: MemoryLayout<CVertex>.stride * 6, index: 0)

            var _viewPort: vector_float2 = vector2(Float(viewPort.width), Float(viewPort.height))
            withUnsafePointer(to: &_viewPort) { pointer in
                renderEncoder?.setVertexBytes(pointer,length: MemoryLayout<simd_double2>.size, index: 1)
            }
        
            renderEncoder?.setFragmentTexture(textureOut, index: 1)
            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

            renderEncoder?.endEncoding()
            commandBuffer?.present(view.currentDrawable!)

            commandBuffer?.commit()
        }
    }
}

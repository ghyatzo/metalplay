import MetalKit
import SwiftUI

struct CVertex {
    var position: vector_float2
    var color: vector_float4
}

struct CTriangle {
    
    var position: vector_float2!
    var color: vector_float4!
    static var vertexCount: Int = 3
    
    static func vertices() -> [CVertex] {
        let border: Float = 64
        let _color: vector_float4 = vector4(0.3, 0.2, 0.1, 1)
        return [
            CVertex(position: SIMD2<Float>(0.0 * border, 0.5 * border), color: _color),
            CVertex(position: SIMD2<Float>(-0.5 * border, -0.5 * border), color: _color),
            CVertex(position: SIMD2<Float>(0.5 * border, -0.5 * border), color: _color)
        ]
    }
}

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
        
        mView.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0)
        mView.enableSetNeedsDisplay = false
        
        mView.preferredFramesPerSecond = 60
        
        return mView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // DO NOTHING
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        
        var parent: MetalView
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        
        var viewPixelFormat: MTLPixelFormat!
        var viewPort: MTLViewport!
        
        var library: MTLLibrary!
        var renderPipelineState: MTLRenderPipelineState!
        
        // DATA
        // number of buffer to manage the synchronization
        
        // Core Animation limits the number of drawables that you can use simultaneously
        // in your app. The default limit is 3, but you can set it to 2 with the
        // maximumDrawableCount property (2 and 3 are the only supported values).
        // Because the maximum number of drawables is 3, this sample creates 3 buffer instances.
        // You donʼt need to create more buffer instances than the maximum number of drawables available.
        let maxFramesInFlight = 3
        var inFlightSemaphore: DispatchSemaphore
        var numTriangles = 50
        var triangles: [CTriangle] = []
        var totalVertexCount: Int = 0
        var wavePosition: Float = 0
        
        // Buffers
        var mBuffers: [MTLBuffer] = []
        var _currentBuffer = 0
        
        init(_ parent: MetalView) {
            
            self.parent = parent
            
            if let device = MTLCreateSystemDefaultDevice() {
                self.device = device
            }
            self.commandQueue = device.makeCommandQueue()
            self.viewPixelFormat = .bgra8Unorm
            self.viewPort = MTLViewport()
            
            self.library = device.makeDefaultLibrary()!
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.label = "basic pipeline"
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = viewPixelFormat
            
            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch let error as NSError { print(error) }

            self.triangles = initializeTriangles(numTriangles)

            // Create vertexBuffers
            self.totalVertexCount = 3 * triangles.count
            let _totalVertexBufferSize = totalVertexCount * MemoryLayout<CVertex>.size
            
            mBuffers.reserveCapacity(maxFramesInFlight)
            for i in 0..<maxFramesInFlight {
                let buffer = device.makeBuffer(length: _totalVertexBufferSize, options: .storageModeShared)
                mBuffers.append(buffer!)
                mBuffers[i].label = "Vertex Buffer index: \(i)"
            }
            
            self.inFlightSemaphore = DispatchSemaphore(value: maxFramesInFlight)
            
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            viewPort.width = Double(size.width)
            viewPort.height = Double(size.height)
        }
        
        func draw(in view: MTKView) {
            
            inFlightSemaphore.wait(timeout: .distantFuture)
            
            _currentBuffer = (_currentBuffer + 1) % maxFramesInFlight
            
            updateState()
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexBuffer(mBuffers[_currentBuffer],
                                           offset: 0,
                                           index: Int(InputDataVertices.rawValue))
            
            var _viewPort: vector_float2 = vector2(Float(viewPort.width), Float(viewPort.height))
            withUnsafePointer(to: &_viewPort) { pointer in
                renderEncoder?.setVertexBytes(pointer,
                                              length: MemoryLayout<simd_double2>.size,
                                              index: Int(InputDataViewportSize.rawValue))
            }
            
            renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: totalVertexCount)
            
            renderEncoder?.endEncoding()
            commandBuffer?.present(view.currentDrawable!)
            
            commandBuffer?.addCompletedHandler({ _ in
                    self.inFlightSemaphore.signal()
            })
            
            commandBuffer?.commit()
            
        }
        
        func updateState() {
            
            let _vertices = CTriangle.vertices()
            let _vertexCount = CTriangle.vertexCount
            
            let waveSpeed: Float = 0.09
            let waveMagnitude: Float = 120
            wavePosition += waveSpeed
            
            // vertex Data for the current buffer
            let currentVerticesPointer = mBuffers[_currentBuffer].contents().assumingMemoryBound(to: CVertex.self)
            let currentVertices = UnsafeMutableBufferPointer(start: currentVerticesPointer, count: totalVertexCount)
            
            for n in 0..<numTriangles {
                var triangle = triangles[n]
                triangle.position!.y = sin(triangle.position.x/waveMagnitude + wavePosition)*waveMagnitude
                triangles[n] = triangle
                
                for vertex in 0..<_vertexCount {
                    let currentVertex = n * _vertexCount + vertex
                    currentVertices[currentVertex].position = triangle.position + _vertices[vertex].position
                    currentVertices[currentVertex].color = triangle.color
                }
            }
             
        }
    }
}

func initializeTriangles(_ count: Int) -> [CTriangle]{
    
    let colors: [vector_float4] = [
        vector4(1, 0, 0, 1),
        vector4(0, 1, 0, 1),
        vector4(0, 0, 1, 1),
        vector4(1, 1, 0, 1),
        vector4(0, 1, 1, 1),
        vector4(1, 0, 1, 1)
    ]
    
    let horizontalSpacing: Float = 40.0
    
    var _triangles: [CTriangle] = []
    _triangles.reserveCapacity(count)
    var _position: vector_float2 = vector2(0.0, 0.0)
    
    for t in 0..<count {
        let step = -Float(count)/2.0 + Float(t)
        _position.x = step * horizontalSpacing
        _position.y = 0.0

        _triangles.append(CTriangle(position: _position, color: colors[t % colors.count]))
        
    }
    
    return _triangles
}

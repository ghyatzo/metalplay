//
//  ViewController.m
//  objc-metal
//
//  Created by Camillo Schenone on 13/04/21.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Create a Metal Device
    id<MTLDevice> mtlDevice = MTLCreateSystemDefaultDevice();
    // Create a Command Queue
    id<MTLCommandQueue> mtlCommandQueue = [mtlDevice newCommandQueue];
    
    // Create a CAMetal Layer that will provide a drawable to print on screen and bind it to the view controller.
    CAMetalLayer *metalLayer = [CAMetalLayer layer];
    metalLayer.device=mtlDevice;
    metalLayer.pixelFormat=MTLPixelFormatBGRA8Unorm;
    metalLayer.frame=self.view.bounds;
    [self.view.layer addSublayer:metalLayer];
    
    // Create a library object for the shader functions on the gpu
    id<MTLLibrary> mtlLibrary = [mtlDevice newDefaultLibrary];
    
    id<MTLFunction> vertexShader = [mtlLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentShader = [mtlLibrary newFunctionWithName:@"fragmentShader"];
    
    // Build the Rendering Pipeline
    MTLRenderPipelineDescriptor *mtlRenderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    
    //assign the vertex and fragment functions to the descriptor
    [mtlRenderPipelineDescriptor setVertexFunction:vertexShader];
    [mtlRenderPipelineDescriptor setFragmentFunction:fragmentShader];
    
    //specify the target-texture pixel format, must be the same as the drawable!
    mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=MTLPixelFormatBGRA8Unorm;
    
    //Build the Rendering Pipeline Object
    id<MTLRenderPipelineState> renderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPipelineDescriptor error:nil];
    
    
    // Generate Some Data
    static float quadVertexData[] =
    {
        0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, 0.0, 1.0,
        -0.5,  0.5, 0.0, 1.0,

        0.5,  0.5, 0.0, 1.0,
        0.5, -0.5, 0.0, 1.0,
        -0.5,  0.5, 0.0, 1.0
    };
    //and create a vertex buffer on the GPU with access to the CPU as well.
    id<MTLBuffer> vertexBuffer = [mtlDevice newBufferWithBytes:quadVertexData length:sizeof(quadVertexData) options:MTLResourceOptionCPUCacheModeDefault];
    
    //the initialization of the Metal Objects is complete.
    
    //Set the display link object to call the renderScene method continuously
    // TODO: HOW THE FUCK DO I CALL A METAL VIEW IN A WINDOW FOR FUCK SAKE
    
    // this is the body of the function that will be called repeatedly
    // renderScene() {

    // get the drawable from which to take the texture to be the render target
    id<CAMetalDrawable> frameDrawable = [metalLayer nextDrawable];
    
    // create a render pass descriptor and then an object to encode
    MTLRenderPassDescriptor *mtlRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    // set the render target texture
    mtlRenderPassDescriptor.colorAttachments[0].texture=frameDrawable.texture;
    
    // set the state for the pipeline: Clear the texture before each render pass with a ClearColor background
    mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // create a command buffer
    id<MTLCommandBuffer> mtlCommandBuffer = [mtlCommandQueue commandBuffer];
    
    //and the command encoder to fill it with a GPU command
    id<MTLRenderCommandEncoder> renderEncoder = [mtlCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];
    
    //select the pipeline
    [renderEncoder setRenderPipelineState:renderPipelineState];
    //select the vertex buffer object and the index for the data
    [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    //set the actual draw command
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    //end encoding
    [renderEncoder endEncoding];
    
    // present the drawable texture
    [mtlCommandBuffer presentDrawable:frameDrawable];
    //commit the commandBuffer to the commandqueue
    [mtlCommandBuffer commit];
    
    //}
    
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end

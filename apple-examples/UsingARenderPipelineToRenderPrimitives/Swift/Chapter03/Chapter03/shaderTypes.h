//
//  shaderTypes.h
//  Chapter03
//
//  Created by Camillo Schenone on 16/04/21.
//

#ifndef shaderTypes_h
#define shaderTypes_h

// A handy way of managing buffers without confusion is setting up and enumerator that translates buffer integers into keywords
typedef enum InputData {
    InputDataVertices       = 0,
    InputDataViewportSize   = 1,
} InputData;

#endif /* shaderTypes_h */

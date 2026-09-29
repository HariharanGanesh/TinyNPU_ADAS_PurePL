#ifndef CNN_INT8_H
#define CNN_INT8_H

#include <stdint.h>

// Dimensions for Micro-CNN
#define INPUT_W 32
#define INPUT_H 24
#define CONV1_FILTERS 4
#define CONV2_FILTERS 8
#define DENSE1_NODES 16
#define OUTPUT_CLASSES 3

// Function prototypes
void cnn_init(void);
int8_t cnn_inference_int8(int32_t *thermal_q20_input);

// Internal math functions (exposed for testing/profiling)
void conv2d_3x3_int8(const int8_t* input, int8_t* output, int width, int height, int in_channels, int out_channels, const int8_t* weights, const int8_t* biases);
void maxpool2d_2x2_int8(const int8_t* input, int8_t* output, int width, int height, int channels);
void dense_int8(const int8_t* input, int8_t* output, int in_nodes, int out_nodes, const int8_t* weights, const int8_t* biases);

#endif // CNN_INT8_H

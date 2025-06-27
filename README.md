# Neural Network Shape Detector (ECE385 Final Project)

This project implements a neural network-based shape detector on FPGA using Vivado. The system can identify circles, squares, and triangles from input images.

## Project Structure

```
.
├── src/               # Source files directory
│   ├── rtl/           # RTL design files
│   ├── testbench/     # Testbench files
│   ├── hdmi/          # HDMI interface modules
│   ├── constraints/   # FPGA constraints files
│   ├── python/        # Python scripts
│   └── data/          # Data files
│       ├── images/    # Image data
│       └── weights/   # Neural network weights
└── README.md          # This file
```

## Neural Network Architecture

The neural network uses a fully connected architecture:
- Input layer: 3600 neurons (60x60 pixel images)
- Hidden layer 1: 256 neurons with tanh activation
- Hidden layer 2: 256 neurons with tanh activation
- Hidden layer 3: 256 neurons with ReLU activation
- Output layer: 3 neurons (one for each shape: circle, square, triangle)

The network uses fixed-point Q1.15 format for all calculations. This format uses 1 sign bit and 15 fractional bits, providing a good balance between range (-1 to +0.99997) and precision (0.00003).

## Implementation Steps

### 1. Image and Weight Preparation

First, convert the test images and generate the COE files for the weights and biases:

```bash
# Convert test images to hex format
python src/python/convert_images_to_hex.py

# Convert trained weights to COE format
python src/python/convert_weights_to_coe.py
```

These scripts prepare the necessary files for simulation and synthesis:
- `src/python/convert_images_to_hex.py` takes images from the dataset and converts them to hex format for the test image provider
- `src/python/convert_weights_to_coe.py` loads the trained Keras model from the dataset and converts all weights and biases to the fixed-point Q1.15 format

### 2. Required Files and BRAM IP Creation in Vivado

For each set of weights, biases, and test images, create BRAM IPs in Vivado:

1. Create a new Vivado project with FPGA target device
2. Add all the SystemVerilog files to the project
3. In the IP Catalog, search for "Block Memory Generator"
4. Configure each BRAM with the following settings:
   - Memory Type: Single Port ROM
   - Width: 16 bits (for weights/biases) or 8 bits (for images)
   - Depth: Size of the array
   - Load init file: Select the corresponding COE/hex file
5. Generate and instantiate each BRAM in the project

### 3. Simulation

To test the functionality of the shape detector system:

1. Add the testbench files to the project
2. Run behavioral simulation using `shape_detector_system_tb.sv`
3. The testbench will test four images (circle, square, triangle, and a custom image) and display the detection results

### 4. Implementation

To implement the design on the FPGA:

1. Add design constraints (XDC file) for clock, reset, and I/O pins
2. Run synthesis and implementation
3. Generate bitstream and program the FPGA

## Input Image Handling

The project provides two ways to handle input images:

1. **Test Images**: The `test_image_provider` module loads pre-stored images from memory (BRAMs initialized with hex files). This is useful for testing and demonstration.

2. **Custom Images**: You can add your own test images by converting them to hex format using the `convert_images_to_hex.py` script.

The system allows selecting between different test images at runtime using the `image_select` signal.

## Input/Output Interface

- **System Inputs**:
  - `clk`: System clock
  - `rst_n`: Active-low reset
  - `start_detection`: Trigger signal to start processing an image
  - `image_select`: 2-bit selector for which test image to use (00: circle, 01: square, 10: triangle, 11: custom)

- **System Outputs**:
  - `shape_result`: 2-bit shape classification result
    - 00: Unknown
    - 01: Circle
    - 10: Square
    - 11: Triangle
  - `result_ready`: Indicates a valid shape classification result
  - `system_busy`: Indicates the system is processing an image

## Performance Considerations

The neural network processes one neuron at a time in a sequential manner to minimize resource usage. If higher performance is needed, the design can be parallelized by implementing multiple MAC units, trading off additional FPGA resources for faster processing.

**Note on Implementation:** There were some errors in the way we loaded the weight files that caused issues when running the project. Testing wasn't completely successful - only circle detection works properly. However, after examining all states of the neural network, the pipeline architecture of the neural network is functioning perfectly.

## Future Enhancements

- Implement a more resource-efficient neural network with fewer parameters
- Add more shape classes (hexagon, pentagon, etc.)
- Optimize for real-time processing with pipelined architecture
- Support color input images for more complex pattern recognition
- Interface with a camera for live shape detection 

## Copyright and Usage Rights

This project was created as a final project for ECE385. The HDMI files were taken from Lab 6 of the ECE385 class. This project was completed in partnership with Siddharth Gupta.

The dataset used for training the neural network was obtained from Kaggle: [Four Shapes Dataset](https://www.kaggle.com/datasets/smeschke/four-shapes?resource=download).

**Important Notice:**
- Direct plagiarism of this project is not allowed.
- However, the use of these files to further implement your own project is permitted.
- If you use any part of this project, please provide appropriate attribution.

© 2025. All rights reserved. 

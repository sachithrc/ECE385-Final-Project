import numpy as np
import tensorflow as tf
from tensorflow import keras
import os
import struct

def float_to_fixed_point(val, int_bits=1, frac_bits=15):
    """Convert floating point value to Q1.15 fixed point format."""
    # Q1.15 format range: [-1, 0.99997]
    # Clamp values to the range
    val = max(min(val, 1.0 - 2**(-frac_bits)), -1.0)
    
    # Scale the value to fixed point
    scaled_val = int(val * (2**frac_bits))
    
    # Handle negative numbers (two's complement)
    if scaled_val < 0:
        scaled_val = (1 << (int_bits + frac_bits)) + scaled_val
    
    return scaled_val

def generate_coe_file(weights, filename, int_bits=1, frac_bits=15):
    """Generate COE file for Vivado BRAM IP core."""
    with open(filename, 'w') as f:
        # Write COE file header
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        # Convert each weight to fixed point and write as hex
        weights_flat = weights.flatten()
        for i, weight in enumerate(weights_flat):
            fixed_point = float_to_fixed_point(weight, int_bits, frac_bits)
            hex_val = format(fixed_point & 0xFFFF, '04x')  # 16-bit hex representation
            
            if i < len(weights_flat) - 1:
                f.write(f"{hex_val},\n")
            else:
                f.write(f"{hex_val};\n")
    
    print(f"Generated COE file: {filename}")

def main():
    # Load the model
    model_path = '/Users/sachith/Desktop/archive/shapes_model.h5'
    
    # Check if model exists
    if not os.path.exists(model_path):
        print(f"Model file not found at {model_path}")
        # Try to train a new model using make_model.py
        try:
            print("Attempting to run make_model.py to create a new model...")
            import sys
            sys.path.append('/Users/sachith/Desktop/archive')
            import make_model
        except Exception as e:
            print(f"Error training model: {e}")
            return
    
    try:
        model = keras.models.load_model(model_path)
    except:
        print(f"Error loading model from {model_path}")
        return
    
    # Create output directory for COE files
    output_dir = '/Users/sachith/coe_files'
    os.makedirs(output_dir, exist_ok=True)
    
    # Extract weights from each layer
    weights = model.get_weights()
    
    # Layer 1 weights and biases
    layer1_weights = weights[0]  # Input to Hidden1 weights
    layer1_biases = weights[1]   # Hidden1 biases
    
    # Layer 2 weights and biases
    layer2_weights = weights[2]  # Hidden1 to Hidden2 weights 
    layer2_biases = weights[3]   # Hidden2 biases
    
    # Layer 3 weights and biases
    layer3_weights = weights[4]  # Hidden2 to Hidden3 weights
    layer3_biases = weights[5]   # Hidden3 biases
    
    # Output layer weights and biases
    output_weights = weights[6]  # Hidden3 to Output weights
    output_biases = weights[7]   # Output biases
    
    # Only keep weights for circle, square, and triangle (exclude star)
    # Assuming the order is [triangle, star, square, circle] from make_model.py
    # We want [circle, square, triangle]
    output_weights_filtered = np.vstack([output_weights[:, 3], output_weights[:, 2], output_weights[:, 0]]).T
    output_biases_filtered = np.array([output_biases[3], output_biases[2], output_biases[0]])
    
    # Generate COE files
    generate_coe_file(layer1_weights, f"{output_dir}/layer1_weights.coe")
    generate_coe_file(layer1_biases, f"{output_dir}/layer1_biases.coe")
    generate_coe_file(layer2_weights, f"{output_dir}/layer2_weights.coe")
    generate_coe_file(layer2_biases, f"{output_dir}/layer2_biases.coe")
    generate_coe_file(layer3_weights, f"{output_dir}/layer3_weights.coe")
    generate_coe_file(layer3_biases, f"{output_dir}/layer3_biases.coe")
    generate_coe_file(output_weights_filtered, f"{output_dir}/output_weights.coe")
    generate_coe_file(output_biases_filtered, f"{output_dir}/output_biases.coe")
    
    # Print summary
    print("\nWeights and biases have been converted to COE format.")
    print(f"Files are saved in: {output_dir}")
    print("\nSizes:")
    print(f"Layer 1 weights: {layer1_weights.shape} -> {layer1_weights.size} values")
    print(f"Layer 1 biases: {layer1_biases.shape} -> {layer1_biases.size} values")
    print(f"Layer 2 weights: {layer2_weights.shape} -> {layer2_weights.size} values") 
    print(f"Layer 2 biases: {layer2_biases.shape} -> {layer2_biases.size} values")
    print(f"Layer 3 weights: {layer3_weights.shape} -> {layer3_weights.size} values")
    print(f"Layer 3 biases: {layer3_biases.shape} -> {layer3_biases.size} values") 
    print(f"Output weights: {output_weights_filtered.shape} -> {output_weights_filtered.size} values")
    print(f"Output biases: {output_biases_filtered.shape} -> {output_biases_filtered.size} values")
    
    # Total BRAM requirement estimate
    total_weights = (layer1_weights.size + layer1_biases.size + 
                     layer2_weights.size + layer2_biases.size + 
                     layer3_weights.size + layer3_biases.size + 
                     output_weights_filtered.size + output_biases_filtered.size)
    bram_bytes = total_weights * 2  # 2 bytes per 16-bit value
    print(f"\nTotal number of parameters: {total_weights}")
    print(f"Total BRAM requirement: {bram_bytes} bytes ({bram_bytes/1024:.2f} KB)")

if __name__ == "__main__":
    main() 
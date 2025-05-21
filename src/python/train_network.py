import cv2
import numpy as np
import os
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.utils import to_categorical
import matplotlib.pyplot as plt

# Parameters
img_size = 60  # Size of images for neural network (60x60)
data_dir = os.path.expanduser('~/Desktop/archive/shapes')
output_dir = os.path.expanduser('~/shape_detector_project/weights')

# Create output directory if it doesn't exist
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Function to flatten image data
def flatten(dimData, images):
    images = np.array(images)
    images = images.reshape(len(images), dimData)
    images = images.astype('float32')
    images /= 255
    return images

# Function to convert and save weights to Q1.15 fixed-point format
def save_weights_for_fpga(model, output_dir):
    weights = model.get_weights()
    
    # Create hex files for each layer's weights and biases
    for i, w in enumerate(weights[::2]):  # Get weights (every other item, skipping biases)
        layer_name = f"layer{i+1}"
        print(f"Processing {layer_name} weights, shape: {w.shape}")
        
        # Convert to Q1.15 fixed-point (1 sign bit, 15 fractional bits)
        # Range: [-1, 1-2^-15] ~= [-1, 0.99997]
        w_fixed = np.clip(w, -1.0, 0.99997)
        w_int = np.round(w_fixed * 32768).astype(np.int32)  # Multiply by 2^15
        
        # Save as hex file
        with open(f"{output_dir}/{layer_name}_weights.hex", 'w') as f:
            for weight in w_int.flatten():
                # Handle negative numbers with 2's complement
                if weight < 0:
                    weight = weight + 65536  # 2^16
                hex_val = format(weight & 0xFFFF, '04x')
                f.write(f"{hex_val}\n")
        
        # Also save as COE file
        with open(f"{output_dir}/{layer_name}_weights.coe", 'w') as f:
            f.write("memory_initialization_radix=16;\n")
            f.write("memory_initialization_vector=\n")
            weights_hex = []
            for weight in w_int.flatten():
                if weight < 0:
                    weight = weight + 65536  # 2^16
                hex_val = format(weight & 0xFFFF, '04x')
                weights_hex.append(hex_val)
            f.write(',\n'.join(weights_hex) + ';')
    
    # Save biases
    for i, b in enumerate(weights[1::2]):  # Get biases (every other item, starting from second)
        layer_name = f"layer{i+1}"
        print(f"Processing {layer_name} biases, shape: {b.shape}")
        
        # Convert to Q1.15 fixed-point
        b_fixed = np.clip(b, -1.0, 0.99997)
        b_int = np.round(b_fixed * 32768).astype(np.int32)  # Multiply by 2^15
        
        # Save as hex file
        with open(f"{output_dir}/{layer_name}_biases.hex", 'w') as f:
            for bias in b_int.flatten():
                # Handle negative numbers with 2's complement
                if bias < 0:
                    bias = bias + 65536  # 2^16
                hex_val = format(bias & 0xFFFF, '04x')
                f.write(f"{hex_val}\n")
        
        # Also save as COE file
        with open(f"{output_dir}/{layer_name}_biases.coe", 'w') as f:
            f.write("memory_initialization_radix=16;\n")
            f.write("memory_initialization_vector=\n")
            biases_hex = []
            for bias in b_int.flatten():
                if bias < 0:
                    bias = bias + 65536  # 2^16
                hex_val = format(bias & 0xFFFF, '04x')
                biases_hex.append(hex_val)
            f.write(',\n'.join(biases_hex) + ';')
    
    # Save summary data (layer sizes, total weights)
    with open(f"{output_dir}/network_summary.txt", 'w') as f:
        f.write("Neural Network Weights Summary\n")
        f.write("--------------------------\n")
        f.write(f"Input size: 3600 (60x60 grayscale)\n")
        
        for i, w in enumerate(weights[::2]):
            f.write(f"Layer {i+1}: {w.shape[0]} -> {w.shape[1]}\n")
            f.write(f"  Weights: {w.size} parameters\n")
            f.write(f"  Biases: {weights[i*2+1].size} parameters\n")
            
        f.write(f"\nTotal weights: {sum(w.size for w in weights[::2])} parameters\n")
        f.write(f"Total biases: {sum(b.size for b in weights[1::2])} parameters\n")
        f.write(f"Total parameters: {sum(w.size for w in weights)} parameters\n")

# Load and prepare data
def prepare_data():
    print("Loading data from", data_dir)
    
    # We'll use only circle, square, and triangle for FPGA implementation
    folders = ['circle', 'square', 'triangle']
    images, labels = [], []
    
    # Load data from each folder
    for label, folder in enumerate(folders):
        folder_path = os.path.join(data_dir, folder)
        print(f"Processing {folder} (label {label}) from {folder_path}")
        
        files = os.listdir(folder_path)
        # Limit to 1000 images per class for faster training
        files = files[:1000]
        
        for filename in files:
            if filename.endswith('.png') or filename.endswith('.jpg'):
                img_path = os.path.join(folder_path, filename)
                try:
                    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
                    img = cv2.resize(img, (img_size, img_size))
                    images.append(img)
                    labels.append(label)
                except Exception as e:
                    print(f"Error loading {img_path}: {e}")
    
    # Convert to numpy arrays
    images = np.array(images)
    labels = np.array(labels)
    
    # Shuffle data
    indices = np.random.permutation(len(images))
    images = images[indices]
    labels = labels[indices]
    
    # Split into training and test sets (80% train, 20% test)
    split = int(0.8 * len(images))
    train_images, test_images = images[:split], images[split:]
    train_labels, test_labels = labels[:split], labels[split:]
    
    # Flatten and normalize images
    dataDim = img_size * img_size
    train_data = flatten(dataDim, train_images)
    test_data = flatten(dataDim, test_images)
    
    # Convert labels to one-hot encoding
    num_classes = len(folders)
    train_labels_one_hot = to_categorical(train_labels, num_classes)
    test_labels_one_hot = to_categorical(test_labels, num_classes)
    
    print(f"Training data: {train_data.shape}")
    print(f"Test data: {test_data.shape}")
    
    return train_data, test_data, train_labels_one_hot, test_labels_one_hot, num_classes

# Build and train the model
def train_model(train_data, test_data, train_labels, test_labels, num_classes):
    print("Building model with 64-neuron hidden layers")
    
    # Build the model with the specified architecture
    model = Sequential([
        Dense(64, activation='tanh', input_shape=(3600,)),
        Dense(64, activation='tanh'),
        Dense(64, activation='relu'),
        Dense(num_classes, activation='softmax')
    ])
    
    # Compile the model
    model.compile(optimizer='adam',
                  loss='categorical_crossentropy',
                  metrics=['accuracy'])
    
    # Print model summary
    model.summary()
    
    # Train the model
    print("Training model...")
    history = model.fit(train_data, train_labels,
                        batch_size=32,
                        epochs=25,
                        verbose=1,
                        validation_data=(test_data, test_labels))
    
    # Evaluate the model
    print("Evaluating model...")
    test_loss, test_acc = model.evaluate(test_data, test_labels)
    print(f"Test accuracy: {test_acc:.4f}")
    
    # Plot training history
    plt.figure(figsize=(12, 4))
    
    plt.subplot(1, 2, 1)
    plt.plot(history.history['accuracy'])
    plt.plot(history.history['val_accuracy'])
    plt.title('Model Accuracy')
    plt.ylabel('Accuracy')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Test'], loc='upper left')
    
    plt.subplot(1, 2, 2)
    plt.plot(history.history['loss'])
    plt.plot(history.history['val_loss'])
    plt.title('Model Loss')
    plt.ylabel('Loss')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Test'], loc='upper left')
    
    plt.tight_layout()
    plt.savefig(f"{output_dir}/training_history.png")
    
    return model

# Main execution
if __name__ == "__main__":
    print("Shape Detector Neural Network Training")
    print("======================================")
    
    # Prepare data
    train_data, test_data, train_labels, test_labels, num_classes = prepare_data()
    
    # Train model
    model = train_model(train_data, test_data, train_labels, test_labels, num_classes)
    
    # Save model in standard Keras format
    model.save(f"{output_dir}/shape_detector_model.h5")
    print(f"Model saved to {output_dir}/shape_detector_model.h5")
    
    # Save weights in FPGA-friendly format
    save_weights_for_fpga(model, output_dir)
    print(f"Weights saved to {output_dir} in FPGA-friendly format")
    
    print("Training complete!") 
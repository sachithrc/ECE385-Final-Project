import os
import cv2
import numpy as np
import random

def convert_image_to_hex(image_path, output_path, target_size=(60, 60)):
    """Convert an image to grayscale, resize it, and save as hex values."""
    # Read the image
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    
    if img is None:
        print(f"Error: Could not read image {image_path}")
        return False
    
    # Resize to target size
    img = cv2.resize(img, target_size)
    
    # Write to hex file
    with open(output_path, 'w') as f:
        for y in range(target_size[1]):
            for x in range(target_size[0]):
                # Write as 2-digit hex values
                f.write(f"{img[y, x]:02x}\n")
    
    print(f"Converted {image_path} to {output_path}")
    return True

def create_synthetic_image(shape_type, output_path, size=60):
    """Create a synthetic image of a specific shape."""
    # Create blank image
    img = np.zeros((size, size), dtype=np.uint8)
    
    # Draw shape
    if shape_type == "circle":
        center = (size // 2, size // 2)
        radius = size // 3
        cv2.circle(img, center, radius, 255, -1)
    
    elif shape_type == "square":
        top_left = (size // 4, size // 4)
        bottom_right = (3 * size // 4, 3 * size // 4)
        cv2.rectangle(img, top_left, bottom_right, 255, -1)
    
    elif shape_type == "triangle":
        pts = np.array([
            [size // 2, size // 4],
            [size // 4, 3 * size // 4],
            [3 * size // 4, 3 * size // 4]
        ], np.int32)
        pts = pts.reshape((-1, 1, 2))
        cv2.fillPoly(img, [pts], 255)
    
    # Write to hex file
    with open(output_path, 'w') as f:
        for y in range(size):
            for x in range(size):
                # Write as 2-digit hex values
                f.write(f"{img[y, x]:02x}\n")
    
    print(f"Created synthetic {shape_type} image at {output_path}")
    return True

def main():
    # Define paths
    dataset_dir = "/Users/sachith/Desktop/archive/shapes"
    output_dir = "/Users/sachith/shape_detector_project"
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Check if dataset exists
    if not os.path.exists(dataset_dir):
        print(f"Dataset directory not found: {dataset_dir}")
        print("Creating synthetic images instead...")
        
        # Create synthetic images for basic shapes
        create_synthetic_image("circle", os.path.join(output_dir, "circle_image.hex"))
        create_synthetic_image("square", os.path.join(output_dir, "square_image.hex"))
        create_synthetic_image("triangle", os.path.join(output_dir, "triangle_image.hex"))
        
        # Create a custom image (another circle for demonstration)
        create_synthetic_image("circle", os.path.join(output_dir, "custom_image.hex"))
        
        return
    
    # Process real images from dataset
    shapes = ["circle", "square", "triangle"]
    
    for shape in shapes:
        shape_dir = os.path.join(dataset_dir, shape)
        
        if not os.path.exists(shape_dir):
            print(f"Shape directory not found: {shape_dir}")
            create_synthetic_image(shape, os.path.join(output_dir, f"{shape}_image.hex"))
            continue
        
        # Get all image files in this shape directory
        image_files = [f for f in os.listdir(shape_dir) if f.endswith('.png')]
        
        if not image_files:
            print(f"No images found in {shape_dir}")
            create_synthetic_image(shape, os.path.join(output_dir, f"{shape}_image.hex"))
            continue
        
        # Select a random image from this shape
        random_image = random.choice(image_files)
        image_path = os.path.join(shape_dir, random_image)
        output_path = os.path.join(output_dir, f"{shape}_image.hex")
        
        convert_image_to_hex(image_path, output_path)
    
    # For the custom image, select another random image (e.g., from circle)
    circle_dir = os.path.join(dataset_dir, "circle")
    if os.path.exists(circle_dir):
        image_files = [f for f in os.listdir(circle_dir) if f.endswith('.png')]
        if image_files:
            random_image = random.choice(image_files)
            image_path = os.path.join(circle_dir, random_image)
            output_path = os.path.join(output_dir, "custom_image.hex")
            convert_image_to_hex(image_path, output_path)
        else:
            create_synthetic_image("circle", os.path.join(output_dir, "custom_image.hex"))
    else:
        create_synthetic_image("circle", os.path.join(output_dir, "custom_image.hex"))
    
    print("Image conversion complete!")

if __name__ == "__main__":
    main() 
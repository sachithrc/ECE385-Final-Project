#!/usr/bin/env python3
# Script to generate test image hex files for shape detector simulation

import numpy as np
import os

def generate_circle_image(size=60, radius=25):
    """Generate a binary circle image"""
    img = np.zeros((size, size), dtype=np.uint8)
    center = size // 2
    y, x = np.ogrid[:size, :size]
    dist_from_center = np.sqrt((x - center)**2 + (y - center)**2)
    img[dist_from_center <= radius] = 255
    return img

def generate_square_image(size=60, square_size=40):
    """Generate a binary square image"""
    img = np.zeros((size, size), dtype=np.uint8)
    start = (size - square_size) // 2
    end = start + square_size
    img[start:end, start:end] = 255
    return img

def generate_triangle_image(size=60):
    """Generate a binary triangle image"""
    img = np.zeros((size, size), dtype=np.uint8)
    height = size * 2 // 3
    for y in range(size):
        for x in range(size):
            # Equilateral triangle centered in the image
            if (y >= size//3 and 
                x >= size//2 - (y - size//3) and 
                x <= size//2 + (y - size//3) and
                y <= size//3 + height):
                img[y, x] = 255
    return img

def generate_custom_image(size=60):
    """Generate a custom test pattern (checkerboard)"""
    img = np.zeros((size, size), dtype=np.uint8)
    check_size = size // 10
    for i in range(0, size, check_size):
        for j in range(0, size, check_size):
            if ((i // check_size) + (j // check_size)) % 2 == 0:
                img[i:i+check_size, j:j+check_size] = 255
    return img

def save_as_hex(img, filename):
    """Save image as hex file"""
    with open(filename, 'w') as f:
        for row in img:
            for pixel in row:
                f.write(f"{pixel:02x}\n")
    print(f"Generated {filename}")

def main():
    # Generate the images
    circle = generate_circle_image()
    square = generate_square_image()
    triangle = generate_triangle_image()
    custom = generate_custom_image()
    
    # Save as hex files
    save_as_hex(circle, "circle_image.hex")
    save_as_hex(square, "square_image.hex")
    save_as_hex(triangle, "triangle_image.hex")
    save_as_hex(custom, "custom_image.hex")
    
    print("All test images generated successfully.")

if __name__ == "__main__":
    main() 
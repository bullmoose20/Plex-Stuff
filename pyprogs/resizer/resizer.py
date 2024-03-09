"""
Resize Image Script

This script resizes images in a specified input folder and saves the resized images in an output folder.
It uses the PIL (Python Imaging Library) library to perform the image processing operations.
"""

import os
from PIL import Image

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".bmp", ".webp", ".gif", ".tiff", ".tif")
TARGET_RATIO = 1 / 1.5
MIN_WIDTH = 300
MAX_WIDTH = 2000

def resize_image(image_path, output_folder):
    """
    Resize an image to the desired aspect ratio of 1:1.5 without skewing or adding black borders.
    The resized image is saved as a JPEG file.

    Args:
        image_path (str): The path to the input image file.
        output_folder (str): The path to the output folder where the resized image will be saved.
    """
    # Open the image
    image = Image.open(image_path)
    original_width, original_height = image.size

    if original_width / original_height == TARGET_RATIO:
        # Skip the image if it is already in the desired aspect ratio
        print(f"Skipping {image_path} as it is already in the desired aspect ratio.")
        return

    if original_width / original_height > TARGET_RATIO:
        # If the image is wider than the target aspect ratio, crop the sides
        target_height = original_height
        target_width = int(target_height * TARGET_RATIO)
        padding = (original_width - target_width) // 2
        image = image.crop((padding, 0, original_width - padding, original_height))
    else:
        # If the image is taller than the target aspect ratio, crop the top and bottom
        target_width = original_width
        target_height = int(target_width / TARGET_RATIO)
        padding = (original_height - target_height) // 2
        image = image.crop((0, padding, original_width, original_height - padding))

    # Resize the image to the target dimensions using Lanczos resampling
    resized_image = image.resize((target_width, target_height), Image.LANCZOS)

    # Scale up or down the image width to meet the desired range (300 to 2000)
    resized_width = resized_image.width
    if resized_width < MIN_WIDTH:
        resized_image = resized_image.resize((MIN_WIDTH, int(MIN_WIDTH / TARGET_RATIO)), Image.LANCZOS)
    elif resized_width > MAX_WIDTH:
        resized_image = resized_image.resize((MAX_WIDTH, int(MAX_WIDTH / TARGET_RATIO)), Image.LANCZOS)

    # Save the resized image as a JPG
    output_filename = os.path.splitext(os.path.basename(image_path))[0] + ".jpg"
    output_path = os.path.join(output_folder, output_filename)
    resized_image.save(output_path, "JPEG")

def process_images(input_folder, output_folder):
    """
    Processes all images in the input folder, resizing them and saving the resized images in the output folder.

    Args:
        input_folder (str): The path to the input folder containing the images.
        output_folder (str): The path to the output folder where the resized images will be saved.
    """
    # Create the output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)

    # Traverse the input folder and process each image
    for root, _, files in os.walk(input_folder):
        for file in files:
            file_path = os.path.join(root, file)
            file_extension = os.path.splitext(file_path)[1].lower()

            if file_extension not in IMAGE_EXTENSIONS:
                continue

            # Resize the image and save it
            resize_image(file_path, output_folder)

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        input_folder = input("Please enter the input folder location: ")
    else:
        input_folder = sys.argv[1]

    # Set the output folder path
    output_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")

    # Process the images
    process_images(input_folder, output_folder)

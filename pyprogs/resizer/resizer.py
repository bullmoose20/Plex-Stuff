import argparse
import glob
import logging
import os
import sys
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from PIL import Image

try:
    # Find the .env file
    dotenv_path = find_dotenv(raise_error_if_not_found=True)

    # Load environment variables from .env file
    load_dotenv(dotenv_path)
except OSError:
    print("Error: The .env file was not found. Please make sure it exists in the script's directory.")
    exit(1)

# Retrieve Plex server details from environment variables
# plex_url = os.getenv('PLEX_URL')
# plex_token = os.getenv('PLEX_TOKEN')
# timeout_seconds = int(os.getenv('PLEX_TIMEOUT', 60))  # Default timeout: 60 seconds
max_log_files = int(os.getenv('MAX_LOG_FILES', 10))  # Default number of logs: 10
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()  # Default logging level: INFO

# Extract the script name without the '.py' extension
script_name = os.path.splitext(os.path.basename(sys.argv[0]))[0]

# Define the logs directory
logs_directory = "logs"

# Ensure the "logs" directory exists
if not os.path.exists(logs_directory):
    os.makedirs(logs_directory)

# Generate a unique log filename with timestamp and script name
timestamp = dt.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")

# Set up logging with timestamps and the specified logging level
log_format = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(filename=log_filename, level=getattr(logging, log_level), format=log_format)

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".bmp", ".webp", ".gif", ".tiff", ".tif")
TARGET_RATIO = 1 / 1.5
MIN_WIDTH = 300
MAX_WIDTH = 2000


def clean_up_old_logs():
    global max_log_files

    # Set max_log_files to 1 if it's 0 or negative
    if max_log_files <= 0:
        max_log_files = 1

    # Remove old log files from the 'logs' subdirectory if there are more than the allowed number
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) > max_log_files:
        logging.info(f"existing_logs: {len(existing_logs)} > max_log_files: {max_log_files}")
        oldest_logs = sorted(existing_logs)[:-max_log_files]
        for old_log in oldest_logs:
            os.remove(old_log)


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
        logging.info(f"Skipping {image_path} as it is already in the desired aspect ratio.")
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
    print(f"Processed: {image_path} -> {output_path}")
    logging.info(f"Processed: {image_path} -> {output_path}")


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
    total_images = 0
    processed_images = 0

    for root, _, files in os.walk(input_folder):
        for file in files:
            file_path = os.path.join(root, file)
            file_extension = os.path.splitext(file_path)[1].lower()

            if file_extension not in IMAGE_EXTENSIONS:
                continue

            total_images += 1

            # Resize the image and save it
            resize_image(file_path, output_folder)
            processed_images += 1

    # Log summary
    print("Processing Summary:")
    print(f"Total Images: {total_images}")
    print(f"Processed Images: {processed_images}")
    print(f"Skipped Images: {total_images - processed_images}")
    logging.info("Processing Summary:")
    logging.info(f"Total Images: {total_images}")
    logging.info(f"Processed Images: {processed_images}")
    logging.info(f"Skipped Images: {total_images - processed_images}")


if __name__ == "__main__":
    # Set up argparse to capture command line arguments
    parser = argparse.ArgumentParser(description='Resize images to a specified aspect ratio.')
    parser.add_argument('--input-folder', required=True, help='Path to the folder containing input images.')
    parser.add_argument('--output-folder', default='output', help='Path to the folder where resized images will be saved.')

    args = parser.parse_args()

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    try:
        # Process the images
        process_images(args.input_folder, args.output_folder)
    except FileNotFoundError as e:
        # Log an error if the input folder is not found
        logging.error(f"Error: {e}")
    finally:
        # Call the clean_up_old_logs function
        clean_up_old_logs()

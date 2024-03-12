import argparse
import glob
import logging
import os
import sys
import time
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
# Counter variables for different actions in resize_image function
skipped_crop_images = 0
cropped_sides_images = 0
cropped_top_bottom_images = 0
skipped_scale_images = 0
scaled_up_images = 0
scaled_down_images = 0
total_images = 0
processed_images = 0
skipped_images = 0


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


def get_formatted_duration(seconds):
    units = [('day', 86400), ('hour', 3600), ('minute', 60), ('second', 1)]
    result = []

    for unit_name, unit_seconds in units:
        value, seconds = divmod(seconds, unit_seconds)
        if value > 0:
            unit_name = unit_name if value == 1 else unit_name + 's'
            result.append(f"{int(value):.0f} {unit_name}")

    if not result:
        milliseconds = seconds * 1000
        return "{:.3f} millisecond".format(milliseconds) if milliseconds == 1 else "{:.3f} milliseconds".format(milliseconds)

    return ' '.join(result)


def resize_image(image_path, output_folder, min_width, max_width):
    global skipped_crop_images
    global cropped_sides_images
    global cropped_top_bottom_images
    global skipped_scale_images
    global scaled_up_images
    global scaled_down_images

    # Open the image
    image = Image.open(image_path)
    original_width, original_height = image.size

    # Set target to original in case all is ok
    target_width = original_width
    target_height = original_height

    if original_width / original_height == TARGET_RATIO:
        # Skip the image if it is already in the desired aspect ratio
        print(f"Skipped crop of {image_path} as it is already in the desired aspect ratio.")
        logging.info(f"Skipped crop of {image_path} as it is already in the desired aspect ratio.")
        skipped_crop_images += 1

    if original_width / original_height > TARGET_RATIO:
        # If the image is wider than the target aspect ratio, crop the sides
        target_height = original_height
        target_width = int(target_height * TARGET_RATIO)
        padding = (original_width - target_width) // 2
        image = image.crop((padding, 0, original_width - padding, original_height))
        print(f"Cropped sides {image_path} to desired aspect ratio.")
        logging.info(f"Cropped sides {image_path} to desired aspect ratio.")
        cropped_sides_images += 1

    if original_width / original_height < TARGET_RATIO:
        # If the image is taller than the target aspect ratio, crop the top and bottom
        target_width = original_width
        target_height = int(target_width / TARGET_RATIO)
        padding = (original_height - target_height) // 2
        image = image.crop((0, padding, original_width, original_height - padding))
        print(f"Cropped top and bottom {image_path} to desired aspect ratio.")
        logging.info(f"Cropped top and bottom {image_path} to desired aspect ratio.")
        cropped_top_bottom_images += 1

    # Resize the image to the target dimensions using Lanczos resampling
    resized_image = image.resize((target_width, target_height), Image.LANCZOS)

    # Scale up or down the image width to meet the desired range (1000 to 2000)
    resized_width = resized_image.width
    if resized_width < min_width:
        resized_image = resized_image.resize((min_width, int(min_width / TARGET_RATIO)), Image.LANCZOS)
        print(f"Scaled up {image_path} to {min_width}.")
        logging.info(f"Scaled up {image_path} to {min_width}.")
        scaled_up_images += 1

    if resized_width > max_width:
        resized_image = resized_image.resize((max_width, int(max_width / TARGET_RATIO)), Image.LANCZOS)
        print(f"Scaled down {image_path} to {max_width}.")
        logging.info(f"Scaled down {image_path} to {max_width}.")
        scaled_down_images += 1

    if resized_width == min_width:
        print(f"Skipped scale up {image_path} to {min_width}.")
        logging.info(f"Skipped scale up {image_path} to {min_width}.")
        skipped_scale_images += 1

    if resized_width == max_width:
        print(f"Skipped scale down {image_path} to {max_width}.")
        logging.info(f"Skipped scale down {image_path} to {max_width}.")
        skipped_scale_images += 1

    # Save the resized image as a JPG
    output_filename = os.path.splitext(os.path.basename(image_path))[0] + ".jpg"
    output_path = os.path.join(output_folder, output_filename)
    resized_image.save(output_path, "JPEG")
    print(f"Processed: {image_path} -> {output_path}")
    logging.info(f"Processed: {image_path} -> {output_path}")


def process_images(input_folder, output_folder, min_width, max_width):
    # Create the output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)

    # Traverse the input folder and process each image
    global total_images
    global processed_images
    global skipped_images

    for root, _, files in os.walk(input_folder):
        for file in files:
            file_path = os.path.join(root, file)
            file_extension = os.path.splitext(file_path)[1].lower()

            if file_extension not in IMAGE_EXTENSIONS:
                # Log or print the skipped image information
                print(f"Skipped image {file_path} due to unsupported file extension.")
                logging.info(f"Skipped image {file_path} due to unsupported file extension.")
                skipped_images += 1
                continue

            total_images += 1

            # Resize the image and save it
            resize_image(file_path, output_folder, min_width, max_width)
            processed_images += 1


if __name__ == "__main__":
    # Set up argparse to capture command line arguments
    parser = argparse.ArgumentParser(description='Resize images to a specified aspect ratio.')
    parser.add_argument('--input-folder', required=True, help='Path to the folder containing input images.')
    parser.add_argument('--output-folder', default='output', help='Path to the folder where resized images will be saved.')
    parser.add_argument('--min-width', type=int, default=1000, help='Minimum width for resizing images.')
    parser.add_argument('--max-width', type=int, default=2000, help='Maximum width for resizing images.')

    args = parser.parse_args()

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    try:
        # Record start time
        start_time = time.time()

        # Process the images
        process_images(args.input_folder, args.output_folder, args.min_width, args.max_width)

        # Record end time
        end_time = time.time()

        # Calculate script duration
        script_duration = end_time - start_time

        # Format the duration in a human-readable way
        formatted_duration = get_formatted_duration(script_duration)

        # Log or print the formatted duration
        print(f"Script duration: {formatted_duration}")
        logging.info(f"Script duration: {formatted_duration}")

        # Log detailed summary based on resize_image function
        print("Detailed Summary:")
        print(f"Total Images Processed: {total_images}")
        print(f"Processed Images: {processed_images}")
        print(f"Skipped Images: {skipped_images}")
        print(f"Skipped Crop Images: {skipped_crop_images}")
        print(f"Skipped Scale Images: {skipped_scale_images}")
        print(f"Cropped Sides Images: {cropped_sides_images}")
        print(f"Cropped Top and Bottom Images: {cropped_top_bottom_images}")
        print(f"Scaled Up Images: {scaled_up_images}")
        print(f"Scaled Down Images: {scaled_down_images}")
        logging.info("Detailed Summary:")
        logging.info(f"Total Images Processed: {total_images}")
        logging.info(f"Processed Images: {processed_images}")
        logging.info(f"Skipped Images: {skipped_images}")
        logging.info(f"Skipped Crop Images: {skipped_crop_images}")
        logging.info(f"Skipped Scale Images: {skipped_scale_images}")
        logging.info(f"Cropped Sides Images: {cropped_sides_images}")
        logging.info(f"Cropped Top and Bottom Images: {cropped_top_bottom_images}")
        logging.info(f"Scaled Up Images: {scaled_up_images}")
        logging.info(f"Scaled Down Images: {scaled_down_images}")

    except FileNotFoundError as e:
        # Log an error if the input folder is not found
        logging.error(f"Error: {e}")
    finally:
        # Call the clean_up_old_logs function
        clean_up_old_logs()

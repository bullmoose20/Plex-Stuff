import argparse
import glob
import logging
import math
import os
import sys
import time
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from PIL import Image, ImageDraw, ImageFont

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


def str_to_bool(value):
    if isinstance(value, bool):
        return value
    if value.lower() in {'true', 't', 'yes', 'y', '1'}:
        return True
    elif value.lower() in {'false', 'f', 'no', 'n', '0'}:
        return False
    else:
        raise argparse.ArgumentTypeError(f"Invalid boolean value: {value}")


def get_image_files(folder_path):
    return [f.decode('utf-8') for f in os.listdir(folder_path) if
            os.path.isfile(os.path.join(folder_path, f)) and (f.endswith(b'.jpg') or f.endswith(b'.png')) and not f.decode('utf-8').startswith('!_')]


def create_image_grid(folder_path, num_columns, thumb_size, show_text, save_output_folder, save_original_folder, output_format, jpg_quality):
    thumb_width, thumb_height = thumb_size
    # Determine text color based on show_text value
    text_color = (255, 255, 255) if show_text else (0, 0, 0)

    # Retrieve the image files in the folder
    files = get_image_files(folder_path)

    # Check if there are no image files
    if not files:
        print(f"No image files found in the folder: {folder_path.decode('utf-8')}")
        logging.info(f"No image files found in the folder: {folder_path.decode('utf-8')}")
        return None  # or any other action you want to take

    # Calculate the number of rows needed based on the number of columns and the number of images
    num_rows = len(files) // num_columns + (len(files) % num_columns > 0)

    # Create a new blank image to hold the grid
    grid_size = (num_columns * thumb_size[0], num_rows * (thumb_size[1] + 20) + 20)
    grid_image = Image.new('RGB', grid_size, (0, 0, 0))

    # Create a drawing context
    draw = ImageDraw.Draw(grid_image)

    # Calculate the font size based on the size of the thumbnail image
    font_size = max(int(thumb_height / 16), 8)  # Ensure a minimum font size of 8
    font_size = 12
    font = ImageFont.truetype('arial.ttf', size=font_size)

    # Loop through each image and add it to the grid
    for i, file in enumerate(files):
        # Open the image and resize it to the thumbnail size
        image_path = os.path.join(folder_path.decode('utf-8'), file)  # Decode folder_path to string
        image = Image.open(image_path)
        # Replace this line
        # image.thumbnail(thumb_size, Image.ANTIALIAS)

        # With one of these alternatives:
        image.thumbnail(thumb_size, Image.LANCZOS)
        # image.thumbnail(thumb_size, Image.BOX)

        # Calculate the position of the image on the grid
        col_index = i % num_columns
        row_index = i // num_columns
        x = col_index * thumb_size[0]
        y = row_index * (thumb_size[1] + 20) + 20
        x_offset = (thumb_size[0] - image.size[0]) // 2
        y_offset = (thumb_size[1] - image.size[1]) // 2

        # Calculate the position of the filename text
        filename = os.path.splitext(file)[0]
        # Replace this line
        # text_width, text_height = font.getsize(filename)

        # With one of these alternatives:
        # text_width, text_height = font.getbbox(filename)
        text_bbox = font.getbbox(filename)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]

        text_x = x + (thumb_size[0] - text_width - 20) // 2 + 10
        text_y = y + thumb_size[1] + 5
        box_width = thumb_size[0] - 20
        box_height = text_height
        text_y = y + thumb_size[1] + 5

        # Paste the thumbnail onto the grid
        grid_image.paste(image, (x + x_offset, y + y_offset))

        # Add the filename under the image
        draw.rectangle((x + 10, text_y - 2, x + 10 + box_width, text_y + box_height + 2), fill=(0, 0, 0))
        draw.text((text_x, text_y), filename, font=font, fill=text_color)

    # Draw vertical lines
    for i in range(num_columns + 1):
        x = i * thumb_size[0]
        draw.line((x, 0, x, grid_size[1]), fill=(0, 0, 0))

    # Draw horizontal lines
    for i in range(num_rows + 1):
        y = i * (thumb_size[1] + 20) + 20
        draw.line((0, y, grid_size[0], y), fill=(0, 0, 0))

    # Create an output folder based on the script location
    output_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    print(f"save_output_folder: {save_output_folder}")
    print(f"save_original_folder: {save_original_folder}")

    # Save in the output folder with a timestamp if specified
    if save_output_folder:
        timestamp = dt.now().strftime('%Y%m%d%H%M%S')
        final_image_name = f"!_{os.path.basename(folder_path.decode('utf-8'))}_grid_{timestamp}"
        final_image_path_output = os.path.join(output_folder, final_image_name + f".{output_format.lower()}")
        if output_format.upper() == 'JPG':
            grid_image.save(final_image_path_output, format=output_format, quality=jpg_quality)
        elif output_format.upper() == 'WEBP':
            grid_image.save(final_image_path_output, format=output_format, lossless=True)
        else:
            grid_image.save(final_image_path_output, format=output_format)
        print(f"Final grid image saved in the output folder as {final_image_path_output}")
        logging.info(f"Final grid image saved in the output folder as {final_image_path_output}")

    # Save in the original folder if specified
    if save_original_folder:
        final_image_name = f"!_{os.path.basename(folder_path.decode('utf-8'))}_grid"
        final_image_path_original = os.path.join(folder_path.decode('utf-8'), final_image_name + f".{output_format.lower()}")
        if output_format.upper() == 'JPG':
            grid_image.save(final_image_path_original, format=output_format, quality=jpg_quality)
        elif output_format.upper() == 'WEBP':
            grid_image.save(final_image_path_original, format=output_format, lossless=True)
        else:
            grid_image.save(final_image_path_original, format=output_format)
        print(f"Final grid image saved in the original folder as {final_image_path_original}")
        logging.info(f"Final grid image saved in the original folder as {final_image_path_original}")

    return grid_image


if __name__ == "__main__":
    start_time = time.time()
    parser = argparse.ArgumentParser(description="Create a grid of thumbnails from a folder of images.")
    parser.add_argument("folder_path", type=str, help="Path to the folder containing images")
    parser.add_argument("--num_columns", type=int, default=None,
                        help="Number of columns (default is sqrt of the number of files)")
    parser.add_argument("--thumb_width", type=int, default=200, help="Thumbnail width (default 200)")
    parser.add_argument("--thumb_height", type=int, default=200, help="Thumbnail height (default 200)")
    parser.add_argument("--show_text", default=True, help="Show text under images")
    parser.add_argument("--show_image", action="store_true", help="Show the grid image")
    parser.add_argument("--save_output_folder", default=True, type=str_to_bool, help="Save the grid image in the output folder")
    parser.add_argument("--save_original_folder", default=False, type=str_to_bool, help="Save the grid image in the original folder")
    parser.add_argument("--output_format", type=str, choices=["PNG", "JPG", "WEBP"], default="JPG", help="Output format (default JPG)")
    parser.add_argument("--jpg_quality", type=int, default=95, help="Quality for JPG format (default 95)")

    args = parser.parse_args()

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    # Encode the folder path to handle non-ASCII characters
    folder_path = os.fsencode(args.folder_path)

    # Check if the folder exists
    if not os.path.exists(folder_path):
        print(f"Error: The specified folder '{args.folder_path}' does not exist.")
        logging.error(f"Error: The specified folder '{args.folder_path}' does not exist.")
    else:
        # List files in the folder
        files = get_image_files(folder_path)
        num_columns = args.num_columns if args.num_columns is not None else int(math.sqrt(len(files)))
        thumb_size = (args.thumb_width, args.thumb_height)
        # Ensure show_text defaults to True if not specified
        show_text = args.show_text if args.show_text is not None else True

        # Create the image grid
        grid_image = create_image_grid(
            folder_path, num_columns, thumb_size, show_text,
            args.save_output_folder, args.save_original_folder,
            args.output_format, args.jpg_quality
        )

        # Call the clean_up_old_logs function
        clean_up_old_logs()

        # Show the grid image if specified
        if args.show_image:
            grid_image.show()

        end_time = time.time()  # Record the end time after script execution
        script_duration = end_time - start_time

        print(f"Script duration: {get_formatted_duration(script_duration)}")
        logging.info(f"Script duration: {get_formatted_duration(script_duration)}")

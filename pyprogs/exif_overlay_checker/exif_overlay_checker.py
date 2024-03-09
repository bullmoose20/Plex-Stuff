import argparse
import glob
import logging
import os
import sys
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from PIL import Image
from PIL.ExifTags import TAGS

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


def main(input_folder, verbose):
    overlay_count = 0
    without_overlay_count = 0

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    # logging.info(f"Command line arguments: {' '.join(sys.argv)}")
    logging.info(f"Input folder: {input_folder}")

    total_files = count_files(input_folder)
    current_file_count = 0

    for root, _, files in os.walk(input_folder):
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                file_path = os.path.join(root, file)
                has_overlay, user_comment = check_overlay_in_exif(file_path)
                if has_overlay:
                    overlay_count += 1
                    logging.info(f"FOUND 'overlay' or 'titlecard' in EXIF data for file: {file_path}")
                else:
                    without_overlay_count += 1
                    logging.info(f"No 'overlay' or 'titlecard' in EXIF data for file: {file_path}")

                if user_comment:
                    logging.debug(f"UserComment for file {file_path}: {user_comment}")

                current_file_count += 1
                print_progress(current_file_count, total_files)

    print_summary(overlay_count, without_overlay_count)


def check_overlay_in_exif(file_path):
    try:
        img = Image.open(file_path)
        exif_data = img._getexif()
        user_comment = None

        if exif_data is not None:
            for tag, value in exif_data.items():
                tag_name = TAGS.get(tag, tag)
                if tag_name == "UserComment" and isinstance(value, bytes):
                    user_comment = value.decode("utf-8", errors="replace")

                if isinstance(value, bytes):
                    value = value.decode("utf-8", errors="replace")

                if isinstance(value, str) and 'overlay' in value.lower():
                    return True, user_comment

                if isinstance(value, str) and 'titlecard' in value.lower():
                    return True, user_comment

        return False, user_comment

    except Exception as e:
        logging.error(f"Error processing file: {file_path}")
        logging.exception(e)
        return False, None


def count_files(input_folder):
    return sum(1 for _, _, files in os.walk(input_folder) for file in files if
               file.lower().endswith(('.jpg', '.jpeg', '.png')))


def print_progress(current, total):
    progress = current / total * 100
    print(f"Progress: {current}/{total} - {progress:.2f}%      ", end="\r")


def print_summary(overlay_count, without_overlay_count):
    print("Summary:")
    print(f"Total images with exif data of 'overlay' or 'titlecard': {overlay_count}")
    print(f"Total images without exif data of 'overlay' or 'titlecard': {without_overlay_count}")
    logging.info("Summary:")
    logging.info(f"Total images with exif data of 'overlay' or 'titlecard': {overlay_count}")
    logging.info(f"Total images without exif data of 'overlay' or 'titlecard': {without_overlay_count}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scan images for 'overlay' in EXIF data.")
    parser.add_argument('--input-folder', help='Specify the input folder path.')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose mode with detailed logging.')
    args = parser.parse_args()

    if args.input_folder is None:
        input_folder = input("Enter the path to the input folder: ")
    else:
        input_folder = args.input_folder

    main(input_folder, args.verbose)
    # Call the clean_up_old_logs function
    clean_up_old_logs()

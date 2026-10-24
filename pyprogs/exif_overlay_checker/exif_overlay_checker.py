import argparse
import glob
import logging
import os
import sys
import time
from datetime import datetime as dt
from dotenv import load_dotenv
from PIL import Image
from PIL.ExifTags import TAGS


max_log_files = int(os.getenv("MAX_LOG_FILES", 10))  # Default number of logs: 10

log_level = os.getenv("LOG_LEVEL", "INFO").upper()  # Default logging level: INFO

script_name = os.path.splitext(os.path.basename(sys.argv[0]))[0]

logs_directory = "logs"

timestamp = dt.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]

log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")

log_format = "%(asctime)s - %(levelname)s - %(message)s"


def configure_runtime():
    """Load optional local configuration and initialize CLI output."""
    global logs_directory, max_log_files, script_name, timestamp
    load_dotenv()

    max_log_files = int(os.getenv("MAX_LOG_FILES", 10))  # Default number of logs: 10

    log_level = os.getenv("LOG_LEVEL", "INFO").upper()  # Default logging level: INFO

    script_name = os.path.splitext(os.path.basename(sys.argv[0]))[0]

    logs_directory = "logs"

    if not os.path.exists(logs_directory):
        os.makedirs(logs_directory)

    timestamp = dt.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]

    log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")

    log_format = "%(asctime)s - %(levelname)s - %(message)s"

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
    units = [("day", 86400), ("hour", 3600), ("minute", 60), ("second", 1)]
    result = []

    for unit_name, unit_seconds in units:
        value, seconds = divmod(seconds, unit_seconds)
        if value > 0:
            unit_name = unit_name if value == 1 else unit_name + "s"
            result.append(f"{int(value):.0f} {unit_name}")

    if not result:
        milliseconds = seconds * 1000
        return f"{milliseconds:.3f} millisecond" if milliseconds == 1 else f"{milliseconds:.3f} milliseconds"

    return " ".join(result)


def main(input_folder, verbose):
    global file, file_path, files, overlay_count, user_comment, without_overlay_count
    overlay_count = 0
    without_overlay_count = 0

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info("Scanning image metadata")

    # logging.info(f"Command line arguments: {' '.join(sys.argv)}")
    logging.info(f"Input folder: {input_folder}")

    total_files = count_files(input_folder)
    current_file_count = 0

    start_time = time.time()

    for root, _, files in os.walk(input_folder):
        for file in files:
            if file.lower().endswith((".jpg", ".jpeg", ".png")):
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

    end_time = time.time()
    script_duration = end_time - start_time

    print_summary(overlay_count, without_overlay_count)
    print(f"Script duration: {get_formatted_duration(script_duration)}")
    logging.info(f"Script duration: {get_formatted_duration(script_duration)}")


def check_overlay_in_exif(file_path):
    try:
        with Image.open(file_path) as img:
            exif_data = dict(img.getexif())
            # UserComment commonly lives in the nested EXIF IFD.
            if 34665 in exif_data:
                exif_data.update(img.getexif().get_ifd(34665))
            exif_data.update(getattr(img, "text", {}))
        user_comment = None

        if exif_data is not None:
            for tag, value in exif_data.items():
                tag_name = TAGS.get(tag, tag)
                if tag_name == "UserComment" and isinstance(value, bytes):
                    user_comment = value.decode("utf-8", errors="replace")

                if isinstance(value, bytes):
                    value = value.decode("utf-8", errors="replace")

                if isinstance(value, str) and "overlay" in value.lower():
                    return True, user_comment

                if isinstance(value, str) and "titlecard" in value.lower():
                    return True, user_comment

        return False, user_comment

    except Exception as e:
        logging.error(f"Error processing file: {file_path}")
        logging.exception(e)
        return False, None


def count_files(input_folder):
    return sum(
        1 for _, _, files in os.walk(input_folder) for file in files if file.lower().endswith((".jpg", ".jpeg", ".png"))
    )


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
    configure_runtime()
    parser = argparse.ArgumentParser(description="Scan images for 'overlay' in EXIF data.")
    parser.add_argument("--input-folder", help="Specify the input folder path.")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose mode with detailed logging.")
    args = parser.parse_args()

    if args.input_folder is None:
        input_folder = input("Enter the path to the input folder: ")
    else:
        input_folder = args.input_folder

    main(input_folder, args.verbose)
    # Call the clean_up_old_logs function
    clean_up_old_logs()

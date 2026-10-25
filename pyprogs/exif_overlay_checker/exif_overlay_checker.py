import argparse
import logging
import os
import sys
import time
from dotenv import load_dotenv
from PIL import Image
from PIL.ExifTags import TAGS
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from plex_stuff_helpers import configure_logging, get_formatted_duration, prune_logs, log_configuration


max_log_files, script_name, logs_directory, timestamp = log_configuration()


def configure_runtime():
    """Load optional local configuration and initialize CLI output."""
    global logs_directory, max_log_files, script_name, timestamp
    load_dotenv()

    max_log_files, script_name, logs_directory, timestamp = configure_logging()


def clean_up_old_logs():
    global max_log_files
    max_log_files = prune_logs(logs_directory, script_name, max_log_files)


def main(input_folder, verbose):
    global file, file_path, files, overlay_count, user_comment, without_overlay_count
    overlay_count = 0
    without_overlay_count = 0

    # Log the command along with its arguments
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
    try:
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
    except Exception as error:
        print(f"Command failed ({type(error).__name__}). Check configuration and inputs.")
        raise SystemExit(1) from None

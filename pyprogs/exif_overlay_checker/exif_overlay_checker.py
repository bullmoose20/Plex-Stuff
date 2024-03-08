import os
import logging
from PIL import Image
from PIL.ExifTags import TAGS
import argparse


def main(input_folder, verbose):
    overlay_count = 0
    without_overlay_count = 0

    logging.basicConfig(filename='exif_overlay_log.txt', filemode='w', level=logging.DEBUG if verbose else logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s', encoding='utf-8')

    logging.info(f"Scanning images in folder: {input_folder}")

    total_files = count_files(input_folder)
    current_file_count = 0

    for root, _, files in os.walk(input_folder):
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                file_path = os.path.join(root, file)
                has_overlay, user_comment = check_overlay_in_exif(file_path)
                if has_overlay:
                    overlay_count += 1
                    logging.info(f"FOUND 'overlay' in EXIF data for file: {file_path}")
                else:
                    without_overlay_count += 1
                    logging.info(f"No 'overlay' in EXIF data for file: {file_path}")

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
    print("\nSummary:")
    print(f"Total images with exif data of 'overlay' or 'titlecard': {overlay_count}")
    print(f"Total images without exif data of 'overlay' or 'titlecard': {without_overlay_count}")


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

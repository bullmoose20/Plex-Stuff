from plex_stuff_helpers import append_people_log, determine_image_mode, initialize_people_outputs
import os
import shutil
from PIL import Image


def write_to_log_file(message):
    append_people_log(script_log, message)


def write_to_download_log(message):
    append_people_log(download_log, message)


def copy_file(source, destination):
    shutil.copyfile(source, destination)
    write_to_log_file(f"Copied file from {source} => Saved as: {destination}")


def is_image_file(file_path):
    try:
        Image.open(file_path)
        return True
    except OSError:
        return False


def copy_grayscale_images(directory):
    for root, _, files in os.walk(directory):
        for filename in files:
            file_path = os.path.join(root, filename)
            if is_image_file(file_path):
                image_mode = determine_image_mode(file_path)
                if image_mode == "Grayscale":
                    collection_name, _ = os.path.splitext(filename)
                    new_file_name = os.path.join(download_dir, collection_name + ".jpg")
                    copy_file(file_path, new_file_name)
                    write_to_download_log(f"Copied: {filename} => Saved as: {new_file_name}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Grayscale Image Copier")
    parser.add_argument(
        "-input_directory", metavar="input_directory", type=str, help="Specify the input directory containing images"
    )

    args = parser.parse_args()

    input_directory = args.input_directory

    if not input_directory or not os.path.exists(input_directory):
        print(f'Input directory "{input_directory}" not found. Exiting now...')
        exit()

    script_log, download_log, download_dir = initialize_people_outputs(__file__)

    copy_grayscale_images(input_directory)

    write_to_log_file("#### END ####")

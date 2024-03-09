import os
import shutil
import datetime
from PIL import Image


def write_to_log_file(message):
    with open(script_log, 'a', encoding='utf-8') as log_file:
        log_file.write(f'{datetime.datetime.now()} ~ {message}\n')
    print(f'{datetime.datetime.now()} ~ {message}')


def write_to_download_log(message):
    with open(download_log, 'a', encoding='utf-8') as log_file:
        log_file.write(f'{datetime.datetime.now()} ~ {message}\n')
    print(f'{datetime.datetime.now()} ~ {message}')


def copy_file(source, destination):
    shutil.copyfile(source, destination)
    write_to_log_file(f'Copied file from {source} => Saved as: {destination}')


def determine_image_mode(image_path):
    image = Image.open(image_path)
    image = image.convert('RGB')  # Convert to RGB mode to ensure consistent channel analysis
    pixels = image.getdata()
    channels = image.split()

    r_values = channels[0].getdata()
    g_values = channels[1].getdata()
    b_values = channels[2].getdata()

    color_variation_threshold = 30  # Adjust this threshold based on your requirements

    for r, g, b in zip(r_values, g_values, b_values):
        if abs(r - g) > color_variation_threshold or abs(r - b) > color_variation_threshold or abs(g - b) > color_variation_threshold:
            return 'RGB'

    return 'Grayscale'


def is_image_file(file_path):
    try:
        Image.open(file_path)
        return True
    except (IOError, OSError):
        return False


def copy_grayscale_images(directory):
    for root, _, files in os.walk(directory):
        for filename in files:
            file_path = os.path.join(root, filename)
            if is_image_file(file_path):
                image_mode = determine_image_mode(file_path)
                if image_mode == 'Grayscale':
                    collection_name, _ = os.path.splitext(filename)
                    new_file_name = os.path.join(download_dir, collection_name + ".jpg")
                    copy_file(file_path, new_file_name)
                    write_to_download_log(f'Copied: {filename} => Saved as: {new_file_name}')


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Grayscale Image Copier')
    parser.add_argument('-input_directory', metavar='input_directory', type=str,
                        help='Specify the input directory containing images')

    args = parser.parse_args()

    input_directory = args.input_directory

    if not input_directory or not os.path.exists(input_directory):
        print(f'Input directory "{input_directory}" not found. Exiting now...')
        exit()

    script_path = os.path.dirname(os.path.realpath(__file__))
    script_name = os.path.basename(__file__)
    script_log = os.path.join(script_path, f'{script_name}.log')
    download_log = os.path.join(script_path, f'{script_name}_downloads.log')
    download_dir = os.path.join(script_path, 'Downloads')

    if os.path.exists(script_log):
        os.remove(script_log)

    write_to_log_file("#### START ####")

    os.makedirs(download_dir, exist_ok=True)

    copy_grayscale_images(input_directory)

    write_to_log_file("#### END ####")

import os
import re
import requests
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


def download_file(url, destination):
    response = requests.get(url)
    if response.status_code == 200:
        with open(destination, 'wb') as file:
            file.write(response.content)
        write_to_log_file(f'Downloaded file from {url} => Saved as: {destination}')
    else:
        write_to_log_file(f'Failed to download file from {url}')


def check_existing_file(url, collection_name):
    response = requests.get(url)
    if response.status_code == 200:
        content = response.text
        if collection_name in content:
            write_to_log_file(f'{collection_name} already exists in the file.')
            return True
    return False


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


def determine_image_mode3(image_path):
    image = Image.open(image_path)
    image = image.convert('RGB')

    # Method 1: Color Channel Analysis
    pixels = image.getdata()
    channels = image.split()

    r_values = channels[0].getdata()
    g_values = channels[1].getdata()
    b_values = channels[2].getdata()

    color_variation_threshold = 10

    for r, g, b in zip(r_values, g_values, b_values):
        if abs(r - g) > color_variation_threshold or abs(r - b) > color_variation_threshold or abs(g - b) > color_variation_threshold:
            return 'RGB'

    # Method 2: Saturation Analysis
    saturation_threshold = 0.05

    hsv_image = image.convert('HSV')
    saturation_values = hsv_image.split()[1].getdata()

    for saturation in saturation_values:
        if saturation > saturation_threshold:
            return 'RGB'

    # Method 3: Histogram Analysis
    histogram = image.histogram()
    r_histogram = histogram[0:256]
    g_histogram = histogram[256:512]
    b_histogram = histogram[512:768]

    histogram_threshold = 0.05

    r_max_count = max(r_histogram)
    g_max_count = max(g_histogram)
    b_max_count = max(b_histogram)

    r_ratio = r_max_count / sum(r_histogram)
    g_ratio = g_max_count / sum(g_histogram)
    b_ratio = b_max_count / sum(b_histogram)

    if r_ratio > histogram_threshold or g_ratio > histogram_threshold or b_ratio > histogram_threshold:
        return 'RGB'

    return 'Grayscale'


def download_images(download_urls):
    for url, collection_name in download_urls:
        file_extension = os.path.splitext(url)[1]
        collection_name = collection_name.replace(' (Director)', '').replace(' (Producer)', '').replace(' (Writer)', '')
        file_name = f"{collection_name}{file_extension}"
        new_file_name = os.path.join(download_dir, file_name)

        if not check_existing_file(online_file_url, collection_name):
            download_file(url, new_file_name)
            write_to_download_log(f'Downloaded: {url} => Saved as: {new_file_name}')

            image_mode = determine_image_mode(new_file_name)
            subfolder = None

            if image_mode == 'RGB':
                subfolder = 'color'
            elif image_mode in ['L', 'LA', 'P']:
                subfolder = 'grayscale'
            else:
                subfolder = 'other'

            subfolder_path = os.path.join(download_dir, subfolder)
            os.makedirs(subfolder_path, exist_ok=True)

            new_file_path = os.path.join(subfolder_path, file_name)
            # Overwrite the destination file if it already exists
            if os.path.exists(new_file_path):
                os.remove(new_file_path)

            os.rename(new_file_name, new_file_path)
            write_to_download_log(f'Image mode: {image_mode} => Saved to subfolder: {subfolder}')


if __name__ == "__main__":
    import argparse

    online_file_url = 'https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-People-rainier/master/README.md'

    parser = argparse.ArgumentParser(description='PMM Missing People Downloader')
    parser.add_argument('-metalog_location', metavar='metalog_location', type=str,
                        help='Specify the logs folder location for PMM')

    args = parser.parse_args()

    metalog_location = args.metalog_location

    if not metalog_location or not os.path.exists(metalog_location):
        print(f'Logs location "{metalog_location}" not found. Exiting now...')
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

    input_files = [file for file in os.listdir(metalog_location) if
                   file.startswith('meta') and os.path.isfile(os.path.join(metalog_location, file))]

    for item in input_files:
        item_path = os.path.join(metalog_location, item)
        the_output = os.path.basename(item)
        write_to_log_file(f'Working on: {the_output}')

        with open(item_path, 'r', encoding='utf-8') as input_file:
            content = input_file.read()

        pattern = r'\[\d\d\d\d-\d\d-\d\d .*\[.*\] *\| Detail: tmdb_person updated poster to \[URL\] (https.*)(\..*g) *\|\n.*\n.*\n.*Finished (.*) Collection'
        matches = re.findall(pattern, content)

        if len(matches) == 0:
            write_to_log_file('0 items found...')
        else:
            download_urls = [(match[0] + match[1], match[2]) for match in matches]
            download_images(download_urls)

    write_to_log_file("#### END ####")

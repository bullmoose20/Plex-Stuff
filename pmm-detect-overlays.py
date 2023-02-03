# requirements
# pip3 install opencv-python
# pip3 install tqdm
import argparse
import cv2
import logging
import os
import datetime
import numpy as np
import time
from tqdm import tqdm
import exifread

logging.basicConfig(filename="detection_log.log", filemode='w', level=logging.INFO, format='%(asctime)s %(message)s')

def detect_overlay_in_exif(target_img_path):
    with open(target_img_path, 'rb') as f:
        tags = exifread.process_file(f)
    # Create an empty array
    exif_array = []
    # hard coding JPG for now, but should use pillow to determine file type
    type = "JPG"

    # For non-PNGs
    if type.format != "PNG":
        # Compile array from tags dict
        for i in tags:
            compile = i, str(tags[i])
            exif_array.append(compile)
        for properties in exif_array:
            if properties[0] != 'JPEGThumbnail':
                # print(': '.join(str(x) for x in properties))
                tmp = (': '.join(str(x) for x in properties))
            if 'overlay' in str(tmp).lower():
                return True
        return False
    if type.format == "PNG":
        image = PngImageFile(image)  # via https://stackoverflow.com/a/58399815
        metadata = PngInfo()

        # Compile array from tags dict
        for i in image.text:
            compile = i, str(image.text[i])
            exif_array.append(compile)

        # If XML metadata, pull out data by identifying data type and gathering useful meta
        if len(exif_array) > 0:
            header = exif_array[0][0]
        else:
            header = ""
            print("No available metadata")

        xml_output = []
        if header.startswith("XML"):
            xml = exif_array[0][1]
            xml_output.extend(xml.splitlines())  # Use splitlines so that you have a list containing each line
            # Remove useless meta tags
            for line in xml.splitlines():
                if "<" not in line:
                    if "xmlns" not in line:
                        # Remove equal signs, quotation marks, /> characters and leading spaces
                        xml_line = re.sub(r'[a-z]*:', '', line).replace('="', ': ')
                        xml_line = xml_line.rstrip(' />')
                        xml_line = xml_line.rstrip('\"')
                        xml_line = xml_line.lstrip(' ')
                        print(xml_line)

        elif header.startswith("Software"):
            print("No available metadata")

        # If no XML, print available metadata
        else:
            for properties in exif_array:
                if properties[0] != 'JPEGThumbnail':
                    print(': '.join(str(x) for x in properties))

    # Explanation for GIF or BMP
    if type.format == "GIF" or type.format == "BMP":
        print("No available metadata")
    #
    # for tag in tags:
    #     print(f"{target_img_path} : EXIF data: {tag}.")
    #     if 'overlay' in str(tag).lower():
    #         return True
    # return False

def detect_embedded_images(source_img_path, target_img_path):
    source = cv2.imread(source_img_path, cv2.IMREAD_GRAYSCALE)
    if source is None:
        logging.error(f"{datetime.datetime.now()} - {source_img_path} - libpng warning: iCCP: known incorrect sRGB profile")
        return False, 0

    target = cv2.imread(target_img_path, cv2.IMREAD_GRAYSCALE)
    if target is None:
        logging.error(f"{datetime.datetime.now()} - {target_img_path} - libpng warning: iCCP: known incorrect sRGB profile")
        return False, 0

    if source.shape[0] > target.shape[0] or source.shape[1] > target.shape[1]:
        logging.error(f"{datetime.datetime.now()} - WARN : {source_img_path} is larger than {target_img_path}")
        return False, 0

    result = cv2.matchTemplate(target, source, cv2.TM_CCOEFF_NORMED)
    loc = np.where(result >= 0.95)

    if len(loc[0]) == 0:
        return False, 0
    return True, result.max()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--source", help="directory with source images", required=True)
    parser.add_argument("-t", "--target", help="directory with target images", required=True)
    args = parser.parse_args()

    source_dir = args.source
    target_dir = args.target

    if not os.path.isdir(source_dir):
        logging.error(f"{datetime.datetime.now()} - {source_dir} is not a valid directory.")
        raise SystemExit

    if not os.path.isdir(target_dir):
        logging.error(f"{datetime.datetime.now()} - {target_dir} is not a valid directory.")
        raise SystemExit

    source_images = [f for f in os.listdir(source_dir) if os.path.isfile(os.path.join(source_dir, f))]

    # Get all target images from target_dir and its subdirectories
    target_images = []
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            target_images.append(os.path.join(root, file))

    if not source_images:
        logging.error(f"{datetime.datetime.now()} - No source images found in {source_dir}.")
        raise SystemExit

    if not target_images:
        logging.error(f"{datetime.datetime.now()} - No target images found in {target_dir}.")
        raise SystemExit

    start_time = time.time()
    total_time = 0
    total_target = len(target_images)
    found = 0
    not_found = 0
    for target_img_path in tqdm(target_images):
        target_start = time.time()
        match_found = False
        if detect_overlay_in_exif(target_img_path):
            logging.info(f"{datetime.datetime.now()} - TRUE : EXIF 'overlay' string found in {target_img_path}")
            continue
        for source_img_path in source_images:
            result, score = detect_embedded_images(os.path.join(source_dir, source_img_path), target_img_path)
            if result:
                logging.info(f"{datetime.datetime.now()} - TRUE : {source_img_path} found in {target_img_path} with score {score}")
                match_found = True
                found += 1
                break
        if not match_found:
            logging.info(f"{datetime.datetime.now()} - FALSE: No source images or EXIF 'overlay' string found in {target_img_path}")
            not_found += 1
        target_end = time.time()
        total_time += target_end - target_start

    end_time = time.time()
    avg_time_per_target = total_time / total_target
    logging.info(f"{datetime.datetime.now()} - Total targets processed: {total_target}")
    logging.info(f"{datetime.datetime.now()} - Total targets found: {found}")
    logging.info(f"{datetime.datetime.now()} - Total targets not found: {not_found}")
    logging.info(f"{datetime.datetime.now()} - Total time to process: {total_time}")
    logging.info(f"{datetime.datetime.now()} - Average time per target: {avg_time_per_target}")

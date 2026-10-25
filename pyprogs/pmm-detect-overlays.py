from PIL import Image

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

if __name__ == "__main__":
    logging.basicConfig(
        filename="detection_log.log", filemode="w", level=logging.INFO, format="%(asctime)s %(message)s"
    )


def detect_overlay_in_exif(target_img_path):
    """Read public Pillow metadata, with ExifRead for additional JPEG tags."""
    with Image.open(target_img_path) as image:
        metadata = dict(image.getexif())
        if 34665 in metadata:
            metadata.update(image.getexif().get_ifd(34665))
        metadata.update(getattr(image, "text", {}))
    if any("overlay" in str(value).lower() for value in metadata.values()):
        return True
    with open(target_img_path, "rb") as stream:
        tags = exifread.process_file(stream)
    return any("overlay" in str(value).lower() for key, value in tags.items() if key != "JPEGThumbnail")


def detect_embedded_images(source_img_path, target_img_path):
    source = cv2.imdecode(np.fromfile(source_img_path, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
    if source is None:
        logging.error(
            f"{datetime.datetime.now()} - {source_img_path} - libpng warning: iCCP: known incorrect sRGB profile"
        )
        return False, 0

    target = cv2.imdecode(np.fromfile(target_img_path, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
    if target is None:
        logging.error(
            f"{datetime.datetime.now()} - {target_img_path} - libpng warning: iCCP: known incorrect sRGB profile"
        )
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
                logging.info(
                    f"{datetime.datetime.now()} - TRUE : {source_img_path} found in {target_img_path} with score {score}"
                )
                match_found = True
                found += 1
                break
        if not match_found:
            logging.info(
                f"{datetime.datetime.now()} - FALSE: No source images or EXIF 'overlay' string found in {target_img_path}"
            )
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

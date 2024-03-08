import argparse
import logging
import os
import os.path
from logging.handlers import RotatingFileHandler
from PIL import Image
from moviepy.video.io.VideoFileClip import VideoFileClip
import numpy as np
import re
import sys
import gc
import datetime
import glob
import time


def setup_logging():
    # Set up logging to both console and a rotating log file
    log_format = '%(asctime)s %(levelname)s: %(message)s'
    logging.basicConfig(level=logging.INFO, format=log_format)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_file = os.path.join(script_dir, 'video_frame_extractor.log')

    # Check if log file exists
    if os.path.exists(log_file):
        # Get the creation time of the existing log file
        creation_time = os.path.getctime(log_file)
        timestamp = datetime.datetime.fromtimestamp(creation_time).strftime('%Y%m%d_%H%M%S')
        # Rename the existing log file with a timestamp
        backup_log_file = f"video_frame_extractor_{timestamp}.log"
        os.rename(log_file, os.path.join(script_dir, backup_log_file))

        # Remove old log files if there are more than 10
        log_files = glob.glob(os.path.join(script_dir, 'video_frame_extractor_*.log'))
        log_files.sort(key=os.path.getctime)
        while len(log_files) >= 10:
            os.remove(log_files.pop(0))

    # Create a rotating file handler and set the formatter
    file_handler = RotatingFileHandler(log_file, maxBytes=1024*1024, backupCount=9)
    file_handler.setFormatter(logging.Formatter(log_format))

    # Add the file handler to the root logger
    logging.getLogger().addHandler(file_handler)


def format_file_name(file_name, is_tv_show):
    if is_tv_show:
        match = re.search(r'S\d+E\d+', file_name)
        episode_info = match.group() if match else ""
        return f"{episode_info}.jpg"
    else:
        return f"{os.path.splitext(file_name)[0]}.jpg"


def take_screenshots(video_file, output_file, frame_extraction_time):
    # Check if the output file already exists, if yes, skip
    if os.path.exists(output_file):
        logging.info(f"Snapshot already exists. Skipping: {output_file}")
        return

    try:
        clip = VideoFileClip(video_file)
        frame = clip.get_frame(frame_extraction_time)
        pil_img = Image.fromarray(np.uint8(frame))

        pil_img.save(output_file)
    except Exception as e:
        logging.error(f"Error during frame extraction: {e}")
    finally:
        try:
            clip.close()
            del clip
        except Exception as e:
            logging.warning(f"Error during cleanup: {e}")


def scan_directory(source_path, frame_extraction_time):
    start_time = time.time()  # Record start time
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "output")
    os.makedirs(output_dir, exist_ok=True)

    video_formats = [".mkv", ".avi", ".mp4", ".mov", ".wmv", ".flv", ".webm", ".m4v"]
    log_file = os.path.join(script_dir, 'video_frame_extractor.log')

    total_added = 0
    total_skipped = 0

    for dirpath, dirnames, filenames in os.walk(source_path):
        output_parent_dir = get_output_parent_dir(source_path, dirpath)
        is_tv_show = has_season_identifier(dirpath)

        for filename in filenames:
            if filename.endswith(tuple(video_formats)):
                video_file = os.path.join(dirpath, filename)
                os.makedirs(output_parent_dir, exist_ok=True)

                output_file = os.path.join(output_parent_dir, format_file_name(filename, is_tv_show))

                if is_tv_show:
                    if not os.path.exists(output_file):
                        create_titlecard_for_season(video_file, output_file, frame_extraction_time)
                        logging.info(f"Title card created for TV show: {output_file}")
                        total_added += 1
                    else:
                        logging.info(f"Title card already exists. Skipping TV show: {output_file}")
                        total_skipped += 1
                else:
                    if not os.path.exists(output_file):
                        create_titlecard_for_movie(video_file, output_file, frame_extraction_time)
                        logging.info(f"Title card created for Movie: {output_file}")
                        total_added += 1
                    else:
                        logging.info(f"Title card already exists. Skipping Movie: {output_file}")
                        total_skipped += 1

    end_time = time.time()  # Record end time
    elapsed_time = end_time - start_time

    # Log summary
    logging.info(f"Total time taken: {elapsed_time:.2f} seconds")
    logging.info(f"Total added: {total_added}")
    logging.info(f"Total skipped: {total_skipped}")


def create_titlecard_for_movie(video_file, output_file, frame_extraction_time):
    take_screenshots(video_file, output_file, frame_extraction_time)


def create_titlecard_for_season(video_file, output_file, frame_extraction_time):
    take_screenshots(video_file, output_file, frame_extraction_time)


def get_output_parent_dir(source_path, dirpath):
    rel_path = get_relative_path(source_path, dirpath)

    # Check if the directory name is "Season #" and adjust the relative path accordingly
    if re.match(r'Season\s\d+', os.path.basename(dirpath)):
        base_name = os.path.basename(os.path.dirname(dirpath))
    else:
        base_name = os.path.basename(dirpath)

    output_parent_dir = os.path.join("output", base_name, rel_path)
    return output_parent_dir


def get_relative_path(base_path, target_path):
    base_path = os.path.abspath(base_path)
    target_path = os.path.abspath(target_path)

    if base_path == target_path:
        return ""

    common_prefix = os.path.commonpath([base_path, target_path])
    rel_path = os.path.relpath(target_path, common_prefix)

    return rel_path


def has_season_identifier1(dirnames):
    return any(re.search(r'Season\s\d+', dir) for dir in dirnames)


def has_season_identifier(dirpath):
    return any(re.search(r'Season\s\d+', path) for path in dirpath.split(os.path.sep))


def main():
    parser = argparse.ArgumentParser(description='Extract title card frames from videos.')
    parser.add_argument('--path', required=True, help='Root directory containing videos.')
    parser.add_argument('--time', type=int, default=45, help='Frame extraction time in seconds (default: 45).')

    args = parser.parse_args()

    setup_logging()

    # Log input values
    logging.info(f"Input --path: {args.path}")
    logging.info(f"Input --time: {args.time} seconds")

    try:
        scan_directory(args.path, args.time)
    finally:
        # Explicitly run garbage collection
        gc.collect()
        # Close open files
        sys.stderr.close()


if __name__ == "__main__":
    main()

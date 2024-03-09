import argparse
import datetime
import gc
import glob
import logging
import numpy as np
import os
import os.path
import re
import sys
import time
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from PIL import Image
from logging.handlers import RotatingFileHandler
from moviepy.video.io.VideoFileClip import VideoFileClip

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
        print(f"Snapshot already exists. Skipping: {output_file}")
        logging.info(f"Snapshot already exists. Skipping: {output_file}")
        return

    try:
        clip = VideoFileClip(video_file)
        frame = clip.get_frame(frame_extraction_time)
        pil_img = Image.fromarray(np.uint8(frame))

        pil_img.save(output_file)
    except Exception as e:
        print(f"Error during frame extraction: {e}")
        logging.error(f"Error during frame extraction: {e}")
    finally:
        try:
            clip.close()
            del clip
        except Exception as e:
            print(f"Error during cleanup: {e}")
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
                        print(f"Title card created for TV show: {output_file}")
                        logging.info(f"Title card created for TV show: {output_file}")
                        total_added += 1
                    else:
                        print(f"Title card already exists. Skipping TV show: {output_file}")
                        logging.info(f"Title card already exists. Skipping TV show: {output_file}")
                        total_skipped += 1
                else:
                    if not os.path.exists(output_file):
                        create_titlecard_for_movie(video_file, output_file, frame_extraction_time)
                        print(f"Title card created for Movie: {output_file}")
                        logging.info(f"Title card created for Movie: {output_file}")
                        total_added += 1
                    else:
                        print(f"Title card already exists. Skipping Movie: {output_file}")
                        logging.info(f"Title card already exists. Skipping Movie: {output_file}")
                        total_skipped += 1

    end_time = time.time()  # Record end time
    elapsed_time = end_time - start_time

    # Log summary
    print(f"Total time taken: {elapsed_time:.2f} seconds")
    print(f"Total added: {total_added}")
    print(f"Total skipped: {total_skipped}")
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

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    try:
        # Check if the specified source_path exists
        if not os.path.exists(args.path):
            print(f"Error: Source path '{args.path}' does not exist.")
            logging.error(f"Error: Source path '{args.path}' does not exist.")
            return  # Exit the script

        scan_directory(args.path, args.time)
    finally:
        # Call the clean_up_old_logs function
        clean_up_old_logs()
        # Explicitly run garbage collection
        gc.collect()
        # Close open files
        sys.stderr.close()


if __name__ == "__main__":
    main()

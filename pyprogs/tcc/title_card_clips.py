import argparse
from pathlib import Path

import gc
import logging
import av
from fractions import Fraction
import math
import os
import os.path
import re
import sys
import time
from dotenv import load_dotenv

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


def format_file_name(file_name, is_tv_show):
    if is_tv_show:
        match = re.search(r"S\d+E\d+", file_name)
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

    if not os.path.isfile(video_file):
        raise FileNotFoundError("Video file not found")
    if not math.isfinite(frame_extraction_time) or frame_extraction_time < 0:
        raise ValueError("Frame extraction time must be within the video duration")
    requested_time = Fraction(str(frame_extraction_time))
    with av.open(os.fspath(video_file)) as container:
        if not container.streams.video:
            raise ValueError("Input contains no video stream")
        stream = container.streams.video[0]
        start_time = (stream.start_time or 0) * stream.time_base
        duration = (
            stream.duration * stream.time_base
            if stream.duration is not None
            else Fraction(container.duration, av.time_base)
            if container.duration is not None
            else None
        )
        if duration is not None and requested_time >= duration:
            raise ValueError("Frame extraction time must be within the video duration")
        target = start_time + requested_time
        # Seek to the preceding keyframe, then decode to the requested presentation
        # timestamp. Frame rate arithmetic is inaccurate for variable-rate video.
        container.seek(int(target / stream.time_base), stream=stream, backward=True, any_frame=False)
        for frame in container.decode(stream):
            if frame.pts is None:
                raise ValueError("Video frame has no presentation timestamp")
            if frame.pts * frame.time_base >= target:
                with frame.to_image() as image:
                    if frame.rotation:
                        with image.rotate(frame.rotation, expand=True) as oriented:
                            oriented.save(output_file)
                    else:
                        image.save(output_file)
                return
        raise ValueError("No video frame at the requested time")


def scan_directory(source_path, frame_extraction_time):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "output")
    os.makedirs(output_dir, exist_ok=True)

    video_formats = [".mkv", ".avi", ".mp4", ".mov", ".wmv", ".flv", ".webm", ".m4v"]

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

    # Log summary
    print(f"Total added: {total_added}")
    print(f"Total skipped: {total_skipped}")
    logging.info(f"Total added: {total_added}")
    logging.info(f"Total skipped: {total_skipped}")


def create_titlecard_for_movie(video_file, output_file, frame_extraction_time):
    take_screenshots(video_file, output_file, frame_extraction_time)


def create_titlecard_for_season(video_file, output_file, frame_extraction_time):
    take_screenshots(video_file, output_file, frame_extraction_time)


def get_output_parent_dir(source_path, dirpath):
    rel_path = get_relative_path(source_path, dirpath)

    # Check if the directory name is "Season #" and adjust the relative path accordingly
    if re.match(r"Season\s\d+", os.path.basename(dirpath)):
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
    return any(re.search(r"Season\s\d+", dir) for dir in dirnames)


def has_season_identifier(dirpath):
    return any(re.search(r"Season\s\d+", path) for path in dirpath.split(os.path.sep))


def main():
    parser = argparse.ArgumentParser(description="Extract title card frames from videos.")
    parser.add_argument("--path", required=True, help="Root directory containing videos.")
    parser.add_argument("--time", type=int, default=45, help="Frame extraction time in seconds (default: 45).")

    args = parser.parse_args()

    # Log the command along with its arguments

    # Record script start time
    start_time = time.time()

    try:
        # Check if the specified source_path exists
        if not os.path.exists(args.path):
            print(f"Error: Source path '{args.path}' does not exist.")
            logging.error(f"Error: Source path '{args.path}' does not exist.")
            return  # Exit the script

        scan_directory(args.path, args.time)
    finally:
        # Record script end time
        end_time = time.time()

        # Calculate script duration
        script_duration = end_time - start_time

        # Log summary
        print("Script completed.")
        print(f"Script duration: {get_formatted_duration(script_duration)}")
        logging.info("Script completed.")
        logging.info(f"Script duration: {get_formatted_duration(script_duration)}")

        # Call the clean_up_old_logs function
        clean_up_old_logs()
        # Explicitly run garbage collection
        gc.collect()
        # Close open files
        sys.stderr.close()


if __name__ == "__main__":
    try:
        configure_runtime()
        main()
    except Exception as error:
        print(f"Command failed ({type(error).__name__}). Check configuration and inputs.")
        raise SystemExit(1) from None

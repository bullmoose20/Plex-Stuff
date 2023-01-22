import logging
import os
import os.path
from PIL import Image
from moviepy.video.io.VideoFileClip import VideoFileClip
import numpy as np
import re
import sys

if len(sys.argv) > 1:
    root_dir = sys.argv[1]
else:
    root_dir = input("Enter the root directory path: ")

def format_file_name(file_name):
    # Extract the S##E## format from the file name
    match = re.search(r"S\d+E\d+", file_name)
    if match:
        episode_info = match.group()
    else:
        episode_info = ""

    return f"{episode_info}.jpg"

def take_screenshots(video_file, output_file):
    clip = VideoFileClip(video_file)
    frame = clip.get_frame(40)
    pil_img = Image.fromarray(np.uint8(frame))
    pil_img.save(output_file)

def scan_directory(root_dir):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "output")
    os.makedirs(output_dir, exist_ok=True)
    video_formats = [".mkv", ".avi", ".mp4", ".mov", ".wmv", ".flv", ".webm", ".m4v"]
    log_file = os.path.join(script_dir, 'title_card_clips_progress.log')
    if os.path.isfile(log_file):
        with open(log_file, 'r') as f:
            scanned_files = set(f.read().splitlines())
    else:
        scanned_files = set()
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(tuple(video_formats)):
                video_file = os.path.join(dirpath, filename)
                if video_file in scanned_files:
                    continue
                rel_path = os.path.relpath(dirpath, root_dir)
                output_subdir = os.path.join(output_dir, rel_path)
                os.makedirs(output_subdir, exist_ok=True)
                episode_match = re.search(r"S\d+E\d+", filename)
                episode = episode_match.group() if episode_match else ""
                output_file = os.path.join(output_subdir, f"{episode}.jpg")
                logging.info(f"Taking screenshot of {video_file} and saving it to {output_file}")
                take_screenshots(video_file, output_file)
                scanned_files.add(video_file)
                with open(log_file, 'a') as f:
                    f.write(video_file + '\n')

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
scan_directory(root_dir)
    
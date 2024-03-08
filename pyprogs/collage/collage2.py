# Script: Collage
# Version: 2.0
# Description: This script creates a grid of thumbnails from a folder of images.
# The user can specify the number of columns, thumbnail size, and whether to show text.
# The script outputs the resulting image grid to a folder called "output".
# Dependencies: PIL (Python Imaging Library)
# Created by: bullmoose20
# Date: 2024-01-20

import os
import math
import argparse
from PIL import Image, ImageDraw, ImageFont
from datetime import datetime


def get_image_files(folder_path):
    return [f.decode('utf-8') for f in os.listdir(folder_path) if
            os.path.isfile(os.path.join(folder_path, f)) and (f.endswith(b'.jpg') or f.endswith(b'.png')) and not f.decode('utf-8').startswith('!_')]


def get_image_files2(folder_path):
    return [f.decode('utf-8') for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f)) and f.endswith(b'.jpg') and not f.decode('utf-8').startswith('!_')]


def create_image_grid(folder_path, num_columns, thumb_size, show_text):
    # Retrieve the image files in the folder
    files = get_image_files(folder_path)

    # Check if there are no image files
    if not files:
        print(f"No image files found in the folder: {folder_path.decode('utf-8')}")
        return None  # or any other action you want to take


def create_image_grid(folder_path, num_columns, thumb_size, show_text):
    thumb_width, thumb_height = thumb_size
    # Determine text color based on show_text value
    text_color = (255, 255, 255) if show_text else (0, 0, 0)

    # Retrieve the image files in the folder
    files = get_image_files(folder_path)

    # Check if there are no image files
    if not files:
        print(f"No image files found in the folder: {folder_path.decode('utf-8')}")
        return None  # or any other action you want to take

    # Calculate the number of rows needed based on the number of columns and the number of images
    num_rows = len(files) // num_columns + (len(files) % num_columns > 0)

    # Create a new blank image to hold the grid
    grid_size = (num_columns * thumb_size[0], num_rows * (thumb_size[1] + 20) + 20)
    grid_image = Image.new('RGB', grid_size, (0, 0, 0))

    # Create a drawing context
    draw = ImageDraw.Draw(grid_image)

    # Calculate the font size based on the size of the thumbnail image
    font_size = max(int(thumb_height / 16), 8)  # Ensure a minimum font size of 8
    font_size = 12
    font = ImageFont.truetype('arial.ttf', size=font_size)

    # Loop through each image and add it to the grid
    for i, file in enumerate(files):
        # Open the image and resize it to the thumbnail size
        image_path = os.path.join(folder_path.decode('utf-8'), file)  # Decode folder_path to string
        image = Image.open(image_path)
        # Replace this line
        # image.thumbnail(thumb_size, Image.ANTIALIAS)

        # With one of these alternatives:
        image.thumbnail(thumb_size, Image.LANCZOS)
        # image.thumbnail(thumb_size, Image.BOX)

        # Calculate the position of the image on the grid
        col_index = i % num_columns
        row_index = i // num_columns
        x = col_index * thumb_size[0]
        y = row_index * (thumb_size[1] + 20) + 20
        x_offset = (thumb_size[0] - image.size[0]) // 2
        y_offset = (thumb_size[1] - image.size[1]) // 2

        # Calculate the position of the filename text
        filename = os.path.splitext(file)[0]
        # Replace this line
        # text_width, text_height = font.getsize(filename)

        # With one of these alternatives:
        # text_width, text_height = font.getbbox(filename)
        text_bbox = font.getbbox(filename)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]

        text_x = x + (thumb_size[0] - text_width - 20) // 2 + 10
        text_y = y + thumb_size[1] + 5
        box_width = thumb_size[0] - 20
        box_height = text_height
        text_y = y + thumb_size[1] + 5

        # Paste the thumbnail onto the grid
        grid_image.paste(image, (x + x_offset, y + y_offset))

        # Add the filename under the image
        draw.rectangle((x + 10, text_y - 2, x + 10 + box_width, text_y + box_height + 2), fill=(0, 0, 0))
        draw.text((text_x, text_y), filename, font=font, fill=text_color)

    # Draw vertical lines
    for i in range(num_columns + 1):
        x = i * thumb_size[0]
        draw.line((x, 0, x, grid_size[1]), fill=(0, 0, 0))

    # Draw horizontal lines
    for i in range(num_rows + 1):
        y = i * (thumb_size[1] + 20) + 20
        draw.line((0, y, grid_size[0], y), fill=(0, 0, 0))

    # Create an output folder based on the script location
    output_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Save in the output folder with a timestamp
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    final_image_name = f"!_{os.path.basename(folder_path.decode('utf-8'))}_grid_{timestamp}"
    final_image_path_output = os.path.join(output_folder, final_image_name + ".jpg")
    grid_image.save(final_image_path_output)
    print(f"Final grid image saved in the output folder as {final_image_path_output}")

    # Save in the original folder
    final_image_name = f"!_{os.path.basename(folder_path.decode('utf-8'))}_grid"
    final_image_path_original = os.path.join(folder_path.decode('utf-8'), final_image_name + ".jpg")
    grid_image.save(final_image_path_original)
    print(f"Final grid image saved in the original folder as {final_image_path_original}")

    return grid_image


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a grid of thumbnails from a folder of images.")
    parser.add_argument("folder_path", type=str, help="Path to the folder containing images")
    parser.add_argument("--num_columns", type=int, default=None,
                        help="Number of columns (default is sqrt of the number of files)")
    parser.add_argument("--thumb_width", type=int, default=200, help="Thumbnail width (default 200)")
    parser.add_argument("--thumb_height", type=int, default=200, help="Thumbnail height (default 200)")
    parser.add_argument("--show_text", default=True, help="Show text under images")
    parser.add_argument("--show_image", action="store_true", help="Show the grid image")

    args = parser.parse_args()

    # Encode the folder path to handle non-ASCII characters
    folder_path = os.fsencode(args.folder_path)

    # Check if the folder exists
    if not os.path.exists(folder_path):
        print(f"Error: The specified folder '{args.folder_path}' does not exist.")
    else:
        # List files in the folder
        files = get_image_files(folder_path)
        num_columns = args.num_columns if args.num_columns is not None else int(math.sqrt(len(files)))
        thumb_size = (args.thumb_width, args.thumb_height)
        # Ensure show_text defaults to True if not specified
        show_text = args.show_text if args.show_text is not None else True

        # Create the image grid
        grid_image = create_image_grid(folder_path, num_columns, thumb_size, show_text)

        # Show the grid image if specified
        if args.show_image:
            grid_image.show()

# Script: Collage
# Version: 1.0
# Description: This script creates a grid of thumbnails from a folder of images.
# The user can specify the number of columns, thumbnail size, and whether to show text.
# The script outputs the resulting image grid to a folder called "output".
# Dependencies: PIL (Python Imaging Library)
# Created by: bullmoose20
# Date: 2023-02-26

from PIL import Image, ImageDraw, ImageFont
import os
import math

# Define the folder where the images are located
folder_path = input("Enter the path to the folder containing images: ")

# Create a list of all the image files in the folder
files = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f)) and f.endswith('.jpg')]

# Define the default number of columns as the square root of the number of files
num_columns = int(math.sqrt(len(files)))

# Prompt the user for the number of columns
num_columns_input = input(f"Enter number of columns (default {num_columns}): ")
if num_columns_input:
    num_columns = int(num_columns_input)

# Prompt user for thumbnail size, defaulting to (200, 200)
thumb_width = input("Enter thumbnail width (default 200): ")
thumb_width = int(thumb_width) if thumb_width else 200

thumb_height = input("Enter thumbnail height (default 200): ")
thumb_height = int(thumb_height) if thumb_height else 200

thumb_size = (thumb_width, thumb_height)

# Prompt the user to show text or not, defaulting to yes
show_text_input = input("Show text under images? (Y/n): ")
show_text = True if show_text_input.lower() in ('', 'y', 'yes') else False

# Determine text color based on show_text value
text_color = (255, 255, 255) if show_text else (0, 0, 0)

# Calculate the number of rows needed based on the number of columns and the number of images
num_rows = len(files) // num_columns + (len(files) % num_columns > 0)

# Create a new blank image to hold the grid
grid_size = (num_columns * thumb_size[0], num_rows * (thumb_size[1] + 20) + 20)
grid_image = Image.new('RGB', grid_size, (0, 0, 0))

# Create a drawing context
draw = ImageDraw.Draw(grid_image)

# Calculate the font size based on the size of the thumbnail image
font_size = max(int(thumb_height / 16), 8)  # Ensure minimum font size of 8
font_size = 12
font = ImageFont.truetype('arial.ttf', size=font_size)

# Loop through each image and add it to the grid
for i, file in enumerate(files):
    # Open the image and resize it to the thumbnail size
    image = Image.open(os.path.join(folder_path, file))
    image.thumbnail(thumb_size, Image.ANTIALIAS)

    # Calculate the position of the image on the grid
    col_index = i % num_columns
    row_index = i // num_columns
    x = col_index * thumb_size[0]
    y = row_index * (thumb_size[1] + 20) + 20
    x_offset = (thumb_size[0] - image.size[0]) // 2
    y_offset = (thumb_size[1] - image.size[1]) // 2

    # Calculate the position of the filename text
    filename = os.path.splitext(file)[0]
    text_width, text_height = font.getsize(filename)
    text_x = x + (thumb_size[0] - text_width - 20) // 2 + 10
    text_y = y + thumb_size[1] + 5
    box_width = thumb_size[0] - 20
    box_height = text_height    # text_x = x + x_offset + (thumb_size[0] - x_offset - text_width) // 2
    text_y = y + thumb_size[1] + 5
    print(f"x: {x}")
    print(f"x_offset: {x_offset}")
    print(f"file: {file}")
    print(f"filename: {filename}")
    print(f"text_width: {text_width}")
    print(f"text_height: {text_height}")
    print(f"thumb_size: {thumb_size}")
    print(f"image.size: {image.size}")
    print(f"box_width: {box_width}")
    print(f"text_x: {text_x}")
    print(f"font_size: {font_size}")
    print(f"text_color: {text_color}")

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
final_image_name = "_".join([os.path.basename(folder_path), "grid"])
final_image_path = os.path.join(output_folder, final_image_name + ".jpg")
grid_image.save(final_image_path)
print(f"Final grid image saved as {final_image_path}")

# Show the grid image
grid_image.show()

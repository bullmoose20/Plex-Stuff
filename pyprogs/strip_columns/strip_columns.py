import os

def strip_characters(input_file, characters_to_remove, output_file=None):
    """
    Remove the first `characters_to_remove` characters from each line in a text file and save the resulting file.

    :param input_file: Path to the input file.
    :param characters_to_remove: Number of characters to remove from the start of each line.
    :param output_file: Path to save the resulting file (optional).
                        If not provided, the input file name will be reused with '_stripped' appended.
    """
    # Read the file into lines with UTF-8 encoding
    with open(input_file, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    # Process each line to remove the specified number of characters
    processed_lines = [line[characters_to_remove:] for line in lines]

    # Generate output file name if not provided
    if not output_file:
        base_name, file_extension = os.path.splitext(input_file)
        output_file = f"{base_name}_stripped{file_extension}"

    # Write the processed lines to the output file with UTF-8 encoding
    with open(output_file, 'w', encoding='utf-8') as file:
        file.write("".join(processed_lines))

    print(f"File processed and saved as: {output_file}")

if __name__ == "__main__":
    import argparse

    # Set up argument parser
    parser = argparse.ArgumentParser(description="Remove the first `xx` characters from each line in a text file.")
    parser.add_argument("input_file", help="Path to the input file.")
    parser.add_argument("characters_to_remove", type=int, help="Number of characters to remove from the start of each line.")
    parser.add_argument("--output_file", help="Path to save the resulting file.", default=None)

    args = parser.parse_args()

    # Call the function
    strip_characters(args.input_file, args.characters_to_remove, args.output_file)

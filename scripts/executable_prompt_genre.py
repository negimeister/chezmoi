import os
import sys
import mutagen
from mutagen.flac import FLAC
import requests



# Function to read the artist and title tags and write to the grouping tag
def process_flac_file(file_path):
    try:
        audio = FLAC(file_path)

        # Check if the 'artist' and 'title' tags exist
        if 'artist' not in audio or 'title' not in audio:
            print("The 'artist' or 'title' tag is missing in the FLAC file.")
        genre = input("Enter Genre: ")

        audio['genre'] = genre
        audio.save()

    except Exception as e:
        print(f"An error occurred: {e}")

# Main entry point
if len(sys.argv) != 2:
    print("Usage: python script.py path/to/your/audiofile.flac")
else:
    file_path = sys.argv[1]
    if os.path.exists(file_path):
        process_flac_file(file_path)
    else:
        print("The specified file does not exist.")

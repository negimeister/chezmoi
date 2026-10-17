import os
import sys
import mutagen
from mutagen.flac import FLAC
import requests

# Function to send the prompt to the Ollama server and get a response
def get_ollama_response(artist_name, title):
    # URL of your Ollama server endpoint
    url = 'http://10.50.1.32:11434/api/generate'
    # Customize the prompt to include both the artist and title
    prompt = f"Give me the transcription and english translation of the following song title. The song is likely a vocaloid or anime song. Give me only the translation and transcription and nothing else. Do not use spaces.  \n'{title}' '{artist_name}'"
    payload = {
        'model': 'mistral:7b',  # Replace 'llama' with the appropriate model you are using
        'prompt': prompt,
        'stream': False
    }
    response = requests.post(url, json=payload)
    print(response.text)
    if response.status_code == 200:
        return response.json().get('response', '').strip()
    else:
        raise Exception(f"Error in Ollama server response: {response.status_code} - {response.text}")

# Function to read the artist and title tags and write to the grouping tag
def process_flac_file(file_path):
    try:
        audio = FLAC(file_path)

        # Check if the 'artist' and 'title' tags exist
        if 'artist' not in audio or 'title' not in audio:
            raise ValueError("The 'artist' or 'title' tag is missing in the FLAC file.")

        artist_name = audio['artist'][0]
        title = audio['title'][0]
        print(f"Artist: {artist_name}")
        print(f"Title: {title}")

        # Get response from the Ollama server
        ollama_response = get_ollama_response(artist_name, title)
        print(f"Ollama response: {ollama_response}")

        # Write the response to the 'grouping' tag
        audio['grouping'] = ollama_response
        audio.save()

        print("The 'grouping' tag has been updated successfully.")

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

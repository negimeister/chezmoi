import sqlite3
import argparse
import re
import mutagen
from mutagen.flac import FLAC
import os

def sanitize_filename(filename):
    # Remove invalid filename characters
    sanitized = re.sub(r'[\\/*?:"<>|]', '', filename)
    return sanitized

def format_track_info(db_path, track_id):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT title, artist, album FROM library WHERE id = ?", (track_id,))
    track_info = cursor.fetchone()
    conn.close()
    return f'{track_id}: {track_info[1]} - {track_info[0]}'

def track_files_must_exist(db_path, clean_up=False):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    print("Checking for non-existent track locations...")

    # Fetch track IDs and locations
    cursor.execute("SELECT id, location FROM track_locations")
    tracks = cursor.fetchall()
    for track in tracks:
        id, path = track
        if not os.path.exists(path):
            print(f"Location refers to non-existent file: {id} - {path}")
            cursor.execute("SELECT id FROM library WHERE location = ?", (path,))
            track_id = cursor.fetchone()
            if track_id is not None:
                print(f"Associated Track: {format_track_info(db_path, track_id[0])}")
            if clean_up:
                # Remove the entry from the database
                cursor.execute("DELETE FROM track_locations WHERE id = ?", (id,))
                print(f"Removed track location {id} from the database.")
                if track_id is not None:
                    cursor.execute("DELETE FROM library WHERE id = ?", (track_id[0],))
                    print(f"Removed track ID {track_id[0]} from the database.")
    
    # Commit changes if cleanup was performed
    if clean_up:
        conn.commit()
        print("Database cleaned up.")

    conn.close()

def tracks_must_have_location(db_path, clean_up=False):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    print("Checking for tracks without a location...")

    # Fetch track IDs
    cursor.execute("SELECT id, location FROM library")
    tracks = cursor.fetchall()
    for track in tracks:
        track_id, location_id = track
        cursor.execute("SELECT location FROM track_locations WHERE id = ?", (location_id,))
        location = cursor.fetchone()
        if location is None:
            print(f"Track ID has no location: {format_track_info(db_path, track_id)}")
            cursor.execute("SELECT artist, title FROM library WHERE id = ?", (track_id,))
            artist, title = cursor.fetchone()
            cursor.execute("SELECT id FROM library WHERE artist = ? AND title = ? AND id <> ?", (artist, title, track_id))
            duplicates = cursor.fetchall()
            if duplicates:
                print(f"Track is also referred to by: {', '.join([str(dup[0]) for dup in duplicates])}")
            if clean_up:
                # Remove the entry from the database
                cursor.execute("DELETE FROM library WHERE id = ?", (track_id,))
                print(f"Removed track ID {track_id} from the database.")
                conn.commit()
    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export music playlists from an SQLite database to m3u8 files.")
    parser.add_argument("db_path", help="Path to the SQLite database")
    parser.add_argument("-x", "--cleanup", action="store_true", help="Clean up non-existent track locations")
    args = parser.parse_args()

    track_files_must_exist(args.db_path, clean_up=args.cleanup)
    tracks_must_have_location(args.db_path, clean_up=args.cleanup)

    print("Operation completed!")


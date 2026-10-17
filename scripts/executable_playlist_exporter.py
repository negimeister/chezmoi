import sqlite3
import argparse
import re

def sanitize_filename(filename):
    # Remove invalid filename characters
    sanitized = re.sub(r'[\\/*?:"<>|]', '', filename)
    return sanitized

def export_playlists_to_m3u8(db_path, output_path):
    # Connect to the SQLite database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Fetch all playlists that are not hidden
    cursor.execute("SELECT id, name FROM Playlists WHERE hidden = 0")
    playlists = cursor.fetchall()

    for playlist in playlists:
        playlist_id, playlist_name = playlist
        sanitized_name = sanitize_filename(playlist_name)
        file_path = f"{output_path}/{sanitized_name}.m3u8"
        
        # Fetch track locations for the playlist sorted by position
        cursor.execute("""
        SELECT tl.filename
        FROM PlaylistTracks pt
        JOIN Library l ON pt.track_id = l.id
        JOIN track_locations tl ON l.location = tl.id
        WHERE pt.playlist_id = ?
        ORDER BY pt.position ASC
        """, (playlist_id,))
        
        filenames = [row[0] for row in cursor.fetchall()]

        # Write the tracks to an m3u8 file, overwriting if it already exists
        with open(file_path, 'w') as m3u8_file:
            for filename in filenames:
                m3u8_file.write('../dj/' + filename.replace( 'mp4', 'flac') + '\n')

        print(f"Exported playlist: {file_path}")

    # Create a special playlist for all tracks in the Library table where mixxx_deleted is set to 0
    cursor.execute("""
    SELECT tl.filename
    FROM Library l
    JOIN track_locations tl ON l.location = tl.id
    WHERE l.mixxx_deleted = 0
    """)
    
    filenames = [row[0] for row in cursor.fetchall()]

    with open("mixxx.m3u8", 'w') as m3u8_file:
        for filename in filenames:
            m3u8_file.write(filename + '\n')

    print("Exported special playlist: all_not_deleted_tracks.m3u8")

    # Create a special playlist for all tracks in the Library table where mixxx_deleted is set to 1
    cursor.execute("""
    SELECT tl.filename
    FROM Library l
    JOIN track_locations tl ON l.location = tl.id
    WHERE l.mixxx_deleted = 1
    """)
    
    filenames = [row[0] for row in cursor.fetchall()]

    with open("mixxx-hidden.m3u8", 'w') as m3u8_file:
        for filename in filenames:
            m3u8_file.write(filename + '\n')

    print("Exported special playlist: all_not_deleted_tracks.m3u8")


    # Close the connection
    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export music playlists from an SQLite database to m3u8 files.")
    parser.add_argument("db_path", help="Path to the SQLite database")
    parser.add_argument("out_path", help="Path to the SQLite database")
    args = parser.parse_args()

    export_playlists_to_m3u8(args.db_path, args.out_path)
    print("Operation completed!")

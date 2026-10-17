import sqlite3
import argparse
import re
import mutagen
from mutagen.flac import FLAC
import sys

def sanitize_filename(filename):
    # Remove invalid filename characters
    sanitized = re.sub(r'[\\/*?:"<>|]', '', filename)
    return sanitized

# hotcue numbers
CATEGORY = 18
GENRE = 19
TAG = 20
ENERGY = 21

# crate IDs
C_VOCALOID = 47
C_ANIME = 48
C_TOUHOU = 25
C_MEMEZ = 20
C_OTHER = 60
C_WTF = 57

G_EDM = 54
G_POPROCK = 53
G_BEATS = 55
G_NOISES = 59

T_ORIGINAL = 51
T_REMIX = 49
T_MEIKYOKU = 50
T_LANGUAGE = 16
T_INSTRUMENTAL = 17
T_RTJT = 30

E_CHILL = 9
E_FUN = 10
E_HYPE = 11

CRATE_SORT = 61


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def format_track_info(db_path, track_id):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT title, artist, album FROM library WHERE id = ?", (track_id,))
    track_info = cursor.fetchone()
    conn.close()
    return f'{track_id}: {track_info[1]} - {track_info[0]}'
    

def add_genre_tag_to_tracks(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Mapping from crate IDs to category letters
    crate_to_letter = {
        C_VOCALOID: 'V', C_ANIME: 'A', C_TOUHOU: 'T', C_MEMEZ: 'M', C_OTHER: 'X',
        G_EDM: 'E', G_POPROCK: 'P', G_BEATS: 'B', G_NOISES: 'N',
        T_ORIGINAL: 'O', T_REMIX: 'R', T_MEIKYOKU: 'M', T_LANGUAGE: 'L', T_INSTRUMENTAL: 'I', T_RTJT: 'J',
        E_CHILL: 'C', E_FUN: 'F', E_HYPE: 'H'
    }

    # Fetch track IDs and locations
    cursor.execute("SELECT id, location FROM library WHERE mixxx_deleted = 0")
    tracks = cursor.fetchall()

    for track_id, location_id in tracks:
        # Fetch the crates the track is in
        cursor.execute("SELECT crate_id FROM crate_tracks WHERE track_id = ?", (track_id,))
        crates = cursor.fetchall()

        # Separate crates into categories, genres, tags, and energy
        category_letters = sorted([crate_to_letter[crate[0]] for crate in crates if crate[0] in [C_VOCALOID, C_ANIME, C_TOUHOU, C_MEMEZ, C_OTHER]])
        genre_letters = sorted([crate_to_letter[crate[0]] for crate in crates if crate[0] in [G_EDM, G_POPROCK, G_BEATS, G_NOISES]])
        tag_letters = sorted([crate_to_letter[crate[0]] for crate in crates if crate[0] in [T_ORIGINAL, T_REMIX, T_MEIKYOKU, T_LANGUAGE, T_INSTRUMENTAL, T_RTJT]])
        energy_letters = sorted([crate_to_letter[crate[0]] for crate in crates if crate[0] in [E_CHILL, E_FUN, E_HYPE]])

        # Combine letters in the required order (category, genre, tag, energy)
        genre_code = ''.join(category_letters + genre_letters + tag_letters + energy_letters)[:4]        # Ensure that the code is 4 letters long
        if(len(genre_code) != 4):
            # check if the track is either deleted or in the sort crate
            cursor.execute("SELECT track_id FROM crate_tracks WHERE track_id = ? AND crate_id = ?", (track_id, CRATE_SORT))
            sort = cursor.fetchone()
            if(sort):
                continue
            eprint(f"Track is missing genre information when it should have it. Genre code: {genre_code}. crates: {crates}; {format_track_info(db_path, track_id)}")


        # Add the genre tag to the FLAC file
        try:
            cursor.execute("SELECT location FROM track_locations WHERE id = ?", (location_id,))
            
            location = cursor.fetchone()
            if not location:
                eprint(f"Track has no location: {format_track_info(db_path, track_id)}")
                continue
            audio = FLAC(location[0])
            audio['GENRE'] = genre_code
            audio.save()
            print(f"Added genre tag {genre_code} to track {format_track_info(db_path, track_id)}")
        except Exception as e:
            eprint(f"Failed to add genre tag to track {format_track_info(db_path, track_id)}: {e}")
    
    conn.close()



def hotcues_to_crates(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    assignments = {
           17: [0, C_VOCALOID, C_ANIME, C_TOUHOU, C_MEMEZ, C_OTHER],
              18: [0, G_EDM, G_POPROCK, G_BEATS, G_NOISES],
                19: [0, T_ORIGINAL, T_REMIX, T_MEIKYOKU, T_LANGUAGE, T_INSTRUMENTAL, T_RTJT],
                    20: [0, E_CHILL, E_FUN, E_HYPE]
    }

    
    #Rember hotcues are 0-indexed
    cursor.execute("SELECT track_id, hotcue, position FROM cues WHERE hotcue >= 17 AND hotcue <= 20")
    cues = cursor.fetchall()
    
    for cue in cues:
        track_id, hotcue, position = cue
        if(position >= assignments[hotcue].__len__() or position < 0):
            eprint("Invalid hotcue position on track", track_id)
        else:
            crate_id = assignments[hotcue][position]
            if crate_id != 0:
                cursor.execute("INSERT INTO crate_tracks (crate_id, track_id) VALUES (?, ?) ON CONFLICT(crate_id, track_id) DO NOTHING", (crate_id, track_id))
  
    conn.commit()  
    conn.close()

def add_hotcues_from_crates(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
    SELECT id FROM library 
        WHERE id NOT IN (
        SELECT track_id FROM cues 
        WHERE hotcue IN (17, 18, 19, 20)
        GROUP BY track_id 
        HAVING COUNT(DISTINCT hotcue) = 4
    ) AND mixxx_deleted = 0
    """)
    tracks = cursor.fetchall()
    assignments = {
        C_VOCALOID: [17, 1],
        C_ANIME: [17, 2],
        C_TOUHOU: [17, 3],
        C_MEMEZ: [17, 4],
        C_OTHER: [17, 5],
        G_EDM: [18, 1],
        G_POPROCK: [18, 2],
        G_BEATS: [18, 3],
        G_NOISES: [18, 4],
        T_ORIGINAL: [19, 1],
        T_REMIX: [19, 2],
        T_MEIKYOKU: [19, 3],
        T_LANGUAGE: [19, 4],
        T_INSTRUMENTAL: [19, 5],
        T_RTJT: [19, 6],
        E_CHILL: [20, 1],
        E_FUN: [20, 2],
        E_HYPE: [20, 3]
    }

    for track in tracks:
        cursor.execute("SELECT crate_id FROM crate_tracks WHERE track_id = ?", (track[0],))
        crates = cursor.fetchall()
        for crate in crates:
            if(crate[0] in assignments):
                hotcue, position = assignments[crate[0]]
                cursor.execute("INSERT INTO cues (track_id, hotcue, position) VALUES (?, ?, ?)", (track[0], hotcue, position))
                print("Adding hotcue to track", track[0], "crate", crate[0], "hotcue", hotcue, "position", position)
    conn.commit()
    conn.close()



def identify_uncategorized_tracks(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM crate_tracks WHERE crate_id = ?", (CRATE_SORT,))
    cursor.execute("""
    SELECT id FROM library 
        WHERE id NOT IN (
        SELECT track_id FROM cues 
        WHERE hotcue IN (17, 18, 19, 20)
        GROUP BY track_id 
        HAVING COUNT(DISTINCT hotcue) = 4
    ) AND mixxx_deleted = 0
    """)

    
    tracks = cursor.fetchall()
    
    for track in tracks:
        print("Adding track to sort crate: ", track[0])
        cursor.execute("INSERT INTO crate_tracks (crate_id, track_id) VALUES (?, ?) ON CONFLICT(crate_id, track_id) DO NOTHING", (CRATE_SORT, track[0]))

    
    tracks = cursor.fetchall()
    conn.commit()
    conn.close()
    
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export music playlists from an SQLite database to m3u8 files.")
    parser.add_argument("db_path", help="Path to the SQLite database")
    args = parser.parse_args()

    hotcues_to_crates(args.db_path)
    add_hotcues_from_crates(args.db_path)
    identify_uncategorized_tracks(args.db_path)
    add_genre_tag_to_tracks(args.db_path)
    print("Operation completed!")

#!/usr/bin/python3
import sqlite3
import os
import sys

def update_record(old_path, new_path):
    # Extract filename and directory from the new path
    new_filename = os.path.basename(new_path)
    new_directory = os.path.dirname(new_path)

    # Connect to the SQLite database
    db_path = os.path.expanduser("~/.mixxx/mixxxdb.sqlite")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Update the record
    try:
        cursor.execute("""
            UPDATE track_locations 
            SET location = ?, filename = ?, directory = ? 
            WHERE location = ?
        """, (new_path, new_filename, new_directory, old_path))
        
        # Commit the changes
        conn.commit()

        # Report the update status
        if cursor.rowcount > 0:
            print(f"Updated {cursor.rowcount} record(s).")
        else:
            print("No records found for the specified old path.")
    
    except sqlite3.Error as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: script_name.py <old_path> <new_path>")
    else:
        old_path = sys.argv[1]
        new_path = sys.argv[2]
        update_record(old_path, new_path)

#!/usr/bin/env python3
import argparse
from mutagen.flac import FLAC
from mutagen import MutagenError
import os
from rich.table import Table
from rich.console import Console
import re

genre_code_regex= r'([VTAXM][PEN][ORJI][CFH]|-)'
track_name_regex= r'track-[A-z,0-9]*\.flac'
stem_name_regex= r'stem-[A-z,0-9]*\.flac'
sus_title_regex = r'(Track [0-9]*)|(.*[uU]ntitled.*)|([uU]nknown.*)'
sus_artist_regex = r'([Un]known [Aa]rtist)'

def track_to_stem(track, stem_dir):
    return os.path.join(stem_dir, os.path.basename(re.sub("flac$", "mp4", track)))

def prompt(flac,question):
    #TODO: figure out how to spawn vlc
    return input(question)

def print_song_details(flac):
    console = Console()
    table = Table(title="Song Details", title_style="bold cyan")
    table.add_column("Attribute", style="bold magenta", justify="right")
    table.add_column("Value", style="bold white")
    #FIXME titles like [snowdrift] don't get printed
    table.add_row("Title", flac.get('title', [""])[0])
    table.add_row("Artist", flac.get('artist', [""])[0])
    table.add_row("Genre",  flac.get('genre', [""])[0])
    table.add_row("Album",  flac.get('album', [""])[0])
    table.add_row("Filename", flac.filename)
    console.print(table)

def check_filename(flac):
    print('Checking filename 🔍')
    if(not re.fullmatch(track_name_regex, os.path.basename(flac.filename))):
        print('Filename is invalid ❌')
        prompt(flac,'Fixing this is not implemented yet...')
    return 'Filename set correctly ✅'

def check_genre(flac):
    print("Checking genre code 🔍")
    genre = flac.get('genre', [""])[0]
    if(not re.fullmatch(genre_code_regex, genre)):
        print("Genre code is not set correctly ❌")
        flac['genre'] = prompt(flac,"Enter new genre code:")
        return False
    return "Genre code is set ✅"

def check_tags(flac):
    print("Checking basic tags 🔍")
    title = flac.get('title', [""])[0].strip()
    artist = flac.get('artist', [""])[0].strip()
    if(not artist):
        print('Track is missing artist')
        flac['artist'] = prompt(flac,"prompt artist: ")
        return False
    elif(re.fullmatch(sus_artist_regex, artist)):
        print('Artist might not be set')
        answer = prompt(flac,"Enter a new artist or press enter to skip")
        if(answer):
            flac['artist'] = answer
            return False
    if(not title):
        print('Track is missing title')
        flac['artist'] = prompt(flac,"prompt title: ")
        return False
    elif(re.fullmatch(sus_title_regex, title)):
        print('Track title mightn to be set properly')
        answer = prompt(flac,"Enter a new title or press enter to skip")
        if(answer):
            flac['title'] = answer
            return False
    return "Basic tags are set ✅"

def check_stems(flac, args):
    stem = track_to_stem(flac.filename, args.stems)
    if(not os.path.exists(stem)):
        prompt(flac, "No stem file found")
    return "Stem file exists ✅"

steps = {"base-tags": check_tags, "genre": check_genre, "filename": check_filename, "stems": check_stems}

parser = argparse.ArgumentParser(description="SoundKlau: A SoundCloud download and track import tool")
parser.add_argument("--steps", nargs="+", default=["base-tags", "genre", "stems"], help="Steps to perform on the tracks. Options: download, convert, tag")
parser.add_argument("-y", type=bool, help="Apply fixes without asking", default=False)
parser.add_argument("--tracks", type=str, default="/home/ngmstr/audio/dj")
parser.add_argument("--stems", type=str, default="/home/ngmstr/audio/stems")

args = parser.parse_args()
for file in os.listdir(args.tracks):
    try:
        flac = FLAC(os.path.join(args.tracks, file))
        print_song_details(flac)
        for step in args.steps:
            result = False
            while(not result):
                result = steps[step](flac, args)
            print(result)

        flac.save()
    except MutagenError as e:
        if(file.endswith(".flac")):
            prompt(flac,f"Failed to decode {file}: {e}")

# TADA:
# stems: check stem file exists. send to splitter if not
# stem-tags: check consistency of tags with stem file. (auto-)merge if broken
# hiding: check if genre - track is hidden in mixxx library

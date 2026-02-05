#!/usr/bin/env python3
# v.0.00.06
# Start of sort_vid_lengths.py

import os
import subprocess
import argparse
import sys
import json # New: For handling our cache file!

# --- Versioning and CLI Flags ---
__version__ = "v.0.00.06" # The current version of our awesome script!

def display_version():
    """Displays the script version and exits."""
    print(f"Video Length Sorter CLI Tool {__version__}")
    sys.exit(0)

# We'll parse arguments upfront to gracefully handle --version and --help flags.
parser = argparse.ArgumentParser(
    description="This script will list video file lengths from longest to shortest, then save the output to 'lengths.txt'.",
    add_help=False # We'll add custom help handling to integrate with -h/--help.
)
parser.add_argument(
    'directory',
    nargs='?', # This makes the directory argument optional.
    default='.', # If no directory is given, we default to the current working directory.
    help='The directory path to search for video files (defaults to the current directory if not specified).'
)
parser.add_argument(
    '-v', '--version',
    action='store_true',
    help='Shows the program\'s version number and then gracefully exits.'
)
parser.add_argument(
    '-h', '--help',
    action='store_true',
    help='Displays this help message and then exits.'
)

args = parser.parse_args()

# Handle version and help flags immediately.
if args.version:
    display_version()

if args.help:
    parser.print_help()
    print("\n--- Important Note ---")
    print("This script relies on 'ffprobe' (a part of the FFmpeg suite) to accurately determine video durations.")
    print("Please ensure FFmpeg is installed and 'ffprobe' is accessible in your system's PATH.")
    sys.exit(0)

# --- Constants ---
OUTPUT_FILENAME = "lengths.txt"
CACHE_FILENAME = "video_lengths_cache.json" # New: Our cache file!
# Common video file extensions for filtering.
VIDEO_EXTENSIONS = ('.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.wmv', '.mpg', '.mpeg', '.3gp', '.ogg', '.ogv')

# --- Cache Management Functions ---
def load_cache() -> dict[str, float]:
    """
    Loads video duration data from the cache file.
    """
    try:
        if os.path.exists(CACHE_FILENAME):
            with open(CACHE_FILENAME, 'r', encoding='utf-8') as f:
                return json.load(f)
    except json.JSONDecodeError:
        print(f"Warning: Cache file '{CACHE_FILENAME}' is corrupted or invalid. Starting with an empty cache.", file=sys.stderr)
    except IOError as e:
        print(f"Warning: Could not read cache file '{CACHE_FILENAME}': {e}. Starting with an empty cache.", file=sys.stderr)
    return {} # Return an empty dictionary if file doesn't exist or has issues

def save_cache(cache_data: dict[str, float]):
    """
    Saves current video duration data to the cache file.
    """
    try:
        with open(CACHE_FILENAME, 'w', encoding='utf-8') as f:
            json.dump(cache_data, f, indent=4) # Use indent for human-readable JSON
    except IOError as e:
        print(f"Error: Could not write to cache file '{CACHE_FILENAME}': {e}", file=sys.stderr)

# --- Helper Functions ---
def format_duration(seconds: float) -> str:
    """
    Converts a duration in seconds into a human-readable HH:MM:SS format.
    Handles potential edge cases for invalid input.
    """
    if seconds is None or seconds < 0 or not isinstance(seconds, (int, float)):
        return 'N/A' # When in doubt, let's just say "Not Applicable".
    
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    remaining_seconds = int(seconds % 60)
    
    # Use f-strings for neat zero-padding!
    return f"{hours:02}:{minutes:02}:{remaining_seconds:02}"

def get_video_duration(file_path: str, cache: dict[str, float]) -> tuple[float | None, bool]:
    """
    Leverages `ffprobe` to extract the duration of a given video file.
    A crucial part of this script, as direct Python duration parsing is complex.
    Now checks cache first!
    Returns duration and a boolean indicating if it was from cache.
    """
    # New: Check cache first!
    if file_path in cache:
        return cache[file_path], True # Found in cache!
    
    try:
        # Construct the ffprobe command to get duration.
        # -v error: Suppress verbose output, only show errors.
        # -show_entries format=duration: Request only the duration entry.
        # -of default=noprint_wrappers=1:nokey=1: Format output to just the value.
        cmd = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            file_path
        ]
        
        # Run the command and capture its output.
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, encoding='utf-8')
        duration_str = result.stdout.strip()
        
        # Convert the string output to a float.
        duration = float(duration_str)
        # Add to cache before returning
        cache[file_path] = duration
        return duration, False # Not from cache
    except FileNotFoundError:
        print(f"Error: 'ffprobe' was not found! Please ensure FFmpeg is installed and in your PATH. Cannot process '{file_path}'.", file=sys.stderr)
        return None, False
    except subprocess.CalledProcessError as e:
        print(f"Error processing '{file_path}' with ffprobe (exit code {e.returncode}): {e.stderr.strip()}", file=sys.stderr)
        return None, False
    except ValueError:
        print(f"Warning: Failed to parse duration for '{file_path}'. Raw output: '{duration_str}'. Skipping.", file=sys.stderr)
        return None, False
    except Exception as e:
        print(f"An unexpected error occurred while getting duration for '{file_path}': {e}", file=sys.stderr)
        return None, False

def find_video_files(root_dir: str, recursive: bool) -> tuple[list[str], bool]:
    """
    Walks through the specified directory (and optionally subdirectories)
    to find all files matching known video extensions.
    Returns a list of absolute file paths and a flag indicating if subdirectories were found.
    """
    video_files = []
    has_subdirectories_found = False # To track if we've ever stepped into a subdirectory.
    
    # os.walk is perfect for traversing directory trees.
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Check if we've entered a subdirectory (not the root itself).
        if os.path.abspath(dirpath) != os.path.abspath(root_dir):
            has_subdirectories_found = True
        
        for filename in filenames:
            # Check if the file's extension is in our list of video extensions.
            if filename.lower().endswith(VIDEO_EXTENSIONS):
                video_files.append(os.path.join(dirpath, filename))
        
        # If we're not searching recursively, we only process the top directory.
        if not recursive and os.path.abspath(dirpath) == os.path.abspath(root_dir):
            # Clear dirnames to prevent os.walk from entering subdirectories.
            dirnames[:] = [] 
            break # Exit after processing the root directory.
        elif not recursive and os.path.abspath(dirpath) != os.path.abspath(root_dir):
            # This case means we somehow entered a subdir despite `dirnames[:] = []`
            # or it's a subsequent iteration of os.walk after the first break condition.
            # To be absolutely sure, let's clear dirnames again.
            dirnames[:] = []
            
    return video_files, has_subdirectories_found

# --- Main Script Logic ---
def main():
    target_directory = os.path.abspath(args.directory)
    print(f"Let's get cracking! Searching for video files in: '{target_directory}'...")

    if not os.path.isdir(target_directory):
        print(f"Oopsie! The directory '{target_directory}' does not exist or isn't a directory. Please check the path and try again.", file=sys.stderr)
        sys.exit(1)

    # First, find all files to determine if subdirectories are even an issue.
    # We temporarily search recursively here to correctly set `has_subdirectories_found`.
    all_potential_files, has_subdirectories_in_full_scan = find_video_files(target_directory, recursive=True)

    if not all_potential_files:
        print(f"Bummer! No video files of known types were found in '{target_directory}' or its subdirectories.")
        sys.exit(0)

    recursive_search_choice = True # Default to recursive for simplicity, adjust if user says no.

    # If subdirectories are indeed present, ask the user what they prefer.
    if has_subdirectories_in_full_scan:
        while True:
            response = input(f"Aha! Subdirectories were detected. Would you like to search recursively through them? (y/n): ").strip().lower()
            if response in ['y', 'yes']:
                recursive_search_choice = True
                break
            elif response in ['n', 'no']:
                recursive_search_choice = False
                break
            else:
                print("Hmm, that wasn't a 'y' or 'n'. Please try again!")

    # Now, filter the files based on the user's recursive choice.
    files_to_process, _ = find_video_files(target_directory, recursive=recursive_search_choice)
    
    if not files_to_process:
        print(f"After applying your search preference ({'recursive' if recursive_search_choice else 'non-recursive'}), no video files were found to process in '{target_directory}'.")
        sys.exit(0)

    print(f"Alright, processing {len(files_to_process)} video files. This might take a moment, depending on your videos and system...")

    # New: Load existing cache at the start
    cache_data = load_cache()

    video_durations = []
    for file_path in files_to_process:
        abs_file_path = os.path.abspath(file_path) # Use absolute path for cache key
        duration, from_cache = get_video_duration(abs_file_path, cache_data)
        
        status_msg = "(from cache)" if from_cache else "(scanning...)"
        print(f"  {os.path.basename(file_path)} {status_msg}") # Live feedback!

        if duration is not None:
            # Use relative path for cleaner output, starting from the target directory.
            relative_path = os.path.relpath(file_path, start=target_directory)
            video_durations.append({'path': relative_path, 'duration': duration})
        else:
            print(f"Skipping '{file_path}' due to an error in retrieving its duration. Onward!", file=sys.stderr)

    if not video_durations:
        print("Looks like we couldn't retrieve durations for any video files. Make sure your files are valid and ffprobe is playing nice.")
        sys.exit(0)

    # The grand sorting! Longest videos first, as per your request.
    video_durations.sort(key=lambda x: x['duration'], reverse=True)

    # Time to write our masterpiece to lengths.txt!
    try:
        with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
            for entry in video_durations:
                f.write(f"{format_duration(entry['duration'])} - {entry['path']}\n")
        print(f"\nSuccess! Your video lengths have been lovingly written to '{OUTPUT_FILENAME}' in the current directory.")
        print("Happy organizing! ✨")
    except IOError as e:
        print(f"Oh dear! An error occurred while trying to write to '{OUTPUT_FILENAME}': {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        # New: Save the updated cache at the end
        save_cache(cache_data)

# This ensures main() runs only when the script is executed directly.
if __name__ == "__main__":
    main()

# End of sort_vid_lengths.py v.0.00.06

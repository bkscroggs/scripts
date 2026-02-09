#!/usr/bin/env python3
# VERSION: 0.1.01
# ==============================================================================
# SCRIPT: video_replacer.py
# PURPOSE: Recursively manages the replacement of original video files with 
#          compressed versions stored in 'CompressedVideos' subdirectories.
#
# This script operates in two safe, distinct phases:
#
# PHASE 1: MOVE & VERIFY
# 1. Recursively searches for all folders named 'CompressedVideos'.
# 2. Moves all files ending in '_compressed.*' from 'CompressedVideos/' up to 
#    the parent directory, KEEPING the '_compressed' suffix for verification.
# 3. In the parent directory, it DELETES all files that DO NOT have the 
#    '_compressed' suffix (i.e., the original files).
# 4. The script PAUSES and prompts the user to manually verify the results.
#
# PHASE 2: RENAME & FINALIZE (Requires User Confirmation)
# 1. If the user confirms, the script iterates through the moved files.
# 2. It strips ONLY the '_compressed' marker, preserving the original file 
#    extension (e.g., 'movie_compressed.mp4' becomes 'movie.mp4').
#
# USAGE:
# 1. Make executable: chmod +x video_replacer.py
# 2. Run from the root directory: ./video_replacer.py
# 3. Run specifying a root directory: ./video_replacer.py /path/to/media
# ==============================================================================
import os
import sys
import argparse
from pathlib import Path

# Define the marker used in filenames that indicates a compressed file
COMPRESSED_MARKER = "_compressed"

def phase_one_move_and_cleanup(root_dir):
    """
    Phase 1: Moves compressed files up, keeps suffix, and deletes originals.
    Returns a set of all parent directories that were modified for Phase 2.
    """
    root_path = Path(root_dir).resolve()
    print(f"--- PHASE 1: MOVE & VERIFY ---")
    print(f"Starting recursive search from: {root_path}")
    
    # Find all 'CompressedVideos' directories recursively
    compressed_video_dirs = list(root_path.rglob('CompressedVideos'))
    modified_parents = set()
    
    if not compressed_video_dirs:
        print("No 'CompressedVideos' directories found. Exiting.")
        return modified_parents

    print(f"Found {len(compressed_video_dirs)} 'CompressedVideos' directories to process.")

    for cv_dir in compressed_video_dirs:
        parent_dir = cv_dir.parent
        modified_parents.add(parent_dir)
        print(f"\nProcessing Parent Directory: {parent_dir}")
        
        # Look for files ending with the marker AND an extension (e.g., *_compressed.mp4)
        compressed_files = list(cv_dir.glob(f'*{COMPRESSED_MARKER}.*'))
        
        if not compressed_files:
            print(f"  No files ending in '*{COMPRESSED_MARKER}.*' found in {cv_dir.name}. Skipping.")
            continue

        moved_count = 0
        
        for comp_file in compressed_files:
            # The target path keeps the full suffix for verification (e.g., movie_compressed.mp4)
            target_path = parent_dir / comp_file.name
            
            print(f"  Moving: '{comp_file.name}' -> '{target_path.name}' (Suffix KEPT)")

            try:
                # 1. Move the file to the parent directory
                comp_file.rename(target_path)
                moved_count += 1
                
                # 2. Cleanup: Delete any file in the parent that is NOT a compressed file
                print(f"    Cleaning up originals in: {parent_dir.name}")
                
                for item in parent_dir.iterdir():
                    # Check if it's a file AND if its name does NOT contain the compressed marker
                    if item.is_file() and COMPRESSED_MARKER not in item.name:
                        print(f"      [DELETING] Original/Other file: {item.name}")
                        item.unlink()
                        
            except Exception as e:
                print(f"  [ERROR] Failed to process {comp_file.name}: {e}")

        if moved_count > 0:
            print(f"  Successfully moved {moved_count} file(s).")
            # Optional: Clean up the now-empty CompressedVideos folder
            try:
                cv_dir.rmdir()
                print(f"  Cleaned up empty directory: {cv_dir}")
            except OSError:
                print(f"  Could not remove directory {cv_dir} (it might not be empty).")
                
    return modified_parents

def phase_two_rename_and_finalize(modified_parents):
    """
    Phase 2: Strips the _compressed marker from files in the verified directories.
    """
    print(f"\n--- PHASE 2: RENAME & FINALIZE ---")
    
    for parent_dir in modified_parents:
        print(f"\nProcessing for renaming in: {parent_dir}")
        
        # Find all files that still have the compressed marker
        files_to_rename = list(parent_dir.glob(f'*{COMPRESSED_MARKER}.*'))
        
        if not files_to_rename:
            print(f"  No files ending in '*{COMPRESSED_MARKER}.*' found to rename.")
            continue
            
        renamed_count = 0
        for file_path in files_to_rename:
            # Example: 'movie_compressed.mp4' -> 'movie.mp4'
            
            # Construct the new name by replacing the specific marker
            new_name_str = file_path.name.replace(COMPRESSED_MARKER, "")
            target_path = file_path.with_name(new_name_str)
            
            print(f"  Renaming: '{file_path.name}' -> '{target_path.name}'")
            
            try:
                file_path.rename(target_path)
                renamed_count += 1
            except Exception as e:
                print(f"  [ERROR] Failed to rename {file_path.name}: {e}")
        
        print(f"  Successfully renamed {renamed_count} file(s) in this directory.")


def main():
    parser = argparse.ArgumentParser(
        description="Staged video replacement script. Phase 1 moves and verifies; Phase 2 renames upon confirmation."
    )
    parser.add_argument(
        '-v', '--version', 
        action='version', 
        version='%(prog)s 0.1.01'
    )
    parser.add_argument(
        'root_directory', 
        nargs='?', 
        default='.', 
        help="The starting directory to search recursively (defaults to current directory)."
    )
    
    args = parser.parse_args()
    
    # --- PHASE 1 ---
    modified_dirs = phase_one_move_and_cleanup(args.root_directory)
    
    if not modified_dirs:
        print("\nScript finished as no modifications were made.")
        return

    # --- VERIFICATION STEP ---
    print("\n" + "="*60)
    print("PHASE 1 COMPLETE. PLEASE VERIFY THE RESULTS NOW.")
    print("Check all parent directories where originals were deleted and compressed files were moved.")
    print("Files currently look like: filename_compressed.ext")
    print("="*60)
    
    while True:
        user_input = input("Are you ready to proceed to Phase 2 (strip '_compressed' marker)? (Y/N): ").strip().upper()
        if user_input == 'Y':
            phase_two_rename_and_finalize(modified_dirs)
            break
        elif user_input == 'N':
            print("Phase 2 aborted by user. Files remain with the '_compressed' marker for manual inspection.")
            break
        else:
            print("Invalid input. Please enter 'Y' or 'N'.")

    print("\nVideo replacement process finished!")

if __name__ == "__main__":
    main()

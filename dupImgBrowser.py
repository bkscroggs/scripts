#!/usr/bin/env python3
# VERSION: v.0.2.12

import os
import curses
import hashlib
import socket
import time
import sys
import subprocess
import json
from collections import defaultdict

# --- Metadata ---
# Version: 0.2.12
# Added: Path highlighting at the point of divergence.
# Added: Intelligent caching (only re-scans if folder timestamp changes).

VERSION = "v.0.2.12"
IMG_EXTS = ('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff')
CACHE_FILE = ".img_dups_cache"

def get_connection_info():
    ssh_conn = os.environ.get("SSH_CONNECTION", "")
    hostname = socket.gethostname()
    user = os.environ.get("USER", "user")
    label = "[ REMOTE ]" if ssh_conn else "[ LOCAL ]"
    return f"{label} {user}@{hostname}"

def get_image_hash(filepath):
    """Generate a quick MD5 hash of the first 8k."""
    hasher = hashlib.md5()
    try:
        with open(filepath, 'rb') as f:
            buf = f.read(8192) 
            hasher.update(buf)
        return hasher.hexdigest()
    except:
        return None

# --- UI Helpers ---

def draw_status(stdscr, message, wait=0.8):
    h, w = stdscr.getmaxyx(); win_w = min(len(message) + 14, w-4)
    win = curses.newwin(3, win_w, h//2 - 1, (w - win_w)//2)
    win.attron(curses.color_pair(2)); win.box(); win.addstr(1, 2, message); win.refresh(); time.sleep(wait)

def draw_popup_confirm(stdscr, message):
    h, w = stdscr.getmaxyx(); win_w = min(len(message) + 12, w-4)
    win = curses.newwin(7, win_w, h//2 - 3, (w - win_w)//2)
    win.attron(curses.color_pair(1)); win.box()
    try: win.addstr(2, 2, message[:win_w-4].center(win_w-4))
    except: pass
    win.addstr(5, 2, "[y] Confirm   [n] Cancel".center(win_w-4), curses.A_BOLD); win.refresh()
    while True:
        ch = win.getch()
        if ch in [ord('y'), ord('Y')]: return True
        if ch in [ord('n'), ord('N'), 27]: return False

def draw_multi_popup(stdscr, title, options):
    h, w = stdscr.getmaxyx()
    win = curses.newwin(len(options) + 4, 45, h//2 - 3, w//2 - 22)
    win.attron(curses.color_pair(1)); win.box()
    win.addstr(1, 2, title, curses.A_BOLD)
    for i, opt in enumerate(options): win.addstr(i + 2, 2, opt)
    win.refresh()
    while True:
        ch = win.getch()
        char = chr(ch).lower() if 0 <= ch < 256 else ""
        if ch in [10, 13]: return options[0][1].lower() 
        for opt in options:
            if char == opt[1].lower(): return opt[1].lower()
        if ch in [27, ord('q')]: return 'c'

# --- Logic & Review UI ---

def find_duplicates(stdscr, directory):
    cache_path = os.path.join(directory, CACHE_FILE)
    dir_mtime = os.path.getmtime(directory)
    
    # Check Cache
    if os.path.exists(cache_path):
        try:
            with open(cache_path, 'r') as f:
                cache_data = json.load(f)
                if cache_data.get("mtime") == dir_mtime:
                    return cache_data.get("lines", [])
        except: pass

    stdscr.clear(); h, w = stdscr.getmaxyx()
    stdscr.addstr(h//2, (w-20)//2, "Scanning images...", curses.A_BOLD); stdscr.refresh()
    
    hashes = defaultdict(list)
    image_files = []
    for root, _, files in os.walk(directory):
        for f in files:
            if f.lower().endswith(IMG_EXTS):
                image_files.append(os.path.join(root, f))
    
    total = len(image_files)
    if total == 0: return []

    for idx, path in enumerate(image_files):
        if idx % 25 == 0:
            stdscr.addstr(h//2 + 1, (w-30)//2, f"Processed: {idx}/{total}"); stdscr.refresh()
        img_hash = get_image_hash(path)
        if img_hash: hashes[img_hash].append(path)
            
    output_lines = []
    for hsh, paths in hashes.items():
        if len(paths) > 1:
            output_lines.append(f"--- SET: {hsh} ---")
            for p in paths: output_lines.append(p)
            output_lines.append("")
            
    # Save Cache
    try:
        with open(cache_path, 'w') as f:
            json.dump({"mtime": dir_mtime, "lines": output_lines}, f)
    except: pass

    return output_lines

def review_duplicates(stdscr, lines, base_dir):
    if not lines:
        draw_status(stdscr, "No duplicates found."); return
        
    curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_CYAN)
    
    selectable_indices = [i for i, line in enumerate(lines) if line.strip() and not line.strip().startswith("---")]
    sel_idx, start_index = 0, 0
    base_dir_abs = os.path.abspath(base_dir).rstrip('/') + '/'
    
    while True:
        stdscr.clear(); h, w = stdscr.getmaxyx()
        current_selection = selectable_indices[sel_idx]
        if current_selection < start_index: start_index = current_selection
        elif current_selection >= start_index + (h-2): start_index = current_selection - (h-2) + 1
        
        stdscr.addstr(0, 0, f" Reviewing Duplicate Images ".ljust(w-1)[:w-1], curses.color_pair(2))
        for i in range(h-2):
            idx = i + start_index
            if idx >= len(lines): break
            content = lines[idx]
            is_selected = (idx == current_selection)
            prefix = "> " if is_selected else "  "
            full_line = f"{prefix}{content}"

            if not content.strip() or content.startswith("---"):
                stdscr.addstr(i + 1, 0, full_line[:w-1].ljust(w-1)[:w-1], curses.color_pair(1))
            elif content.startswith(base_dir_abs):
                # Highlighting logic like Video Browser
                split_point = len(prefix) + len(base_dir_abs)
                stdscr.addstr(i + 1, 0, full_line[:split_point][:w-1], curses.color_pair(2) if is_selected else curses.color_pair(1))
                if split_point < w-1:
                    style = (curses.color_pair(4) | curses.A_BOLD) if is_selected else (curses.color_pair(3) | curses.A_BOLD)
                    stdscr.addstr(i + 1, split_point, full_line[split_point:w-1], style)
            else:
                style = curses.color_pair(2) if is_selected else curses.color_pair(1)
                stdscr.addstr(i + 1, 0, full_line[:w-1].ljust(w-1)[:w-1], style)
        
        stdscr.refresh(); ch = stdscr.getch()
        char = chr(ch).lower() if 0 <= ch < 256 else ""
        
        if ch in [ord('q'), 27, ord('h')]: break
        elif ch in [curses.KEY_UP, ord('k')]: sel_idx = (sel_idx - 1) % len(selectable_indices)
        elif ch in [curses.KEY_DOWN, ord('j')]: sel_idx = (sel_idx + 1) % len(selectable_indices)
        elif ch in [10, 13, ord('l')]: 
            curr = lines[current_selection].strip()
            choice = draw_multi_popup(stdscr, "Action:", ["[v] View Image", "[d] Delete", "[c] Cancel"])
            if choice == 'v':
                subprocess.run(['xdg-open', curr], stderr=subprocess.DEVNULL)
            elif choice == 'd' and draw_popup_confirm(stdscr, f"Delete: {os.path.basename(curr)}?"):
                try: 
                    os.remove(curr); lines[current_selection] = f"--- DELETED: {curr} ---"
                    # Invalidate cache file after a delete
                    cache_path = os.path.join(base_dir, CACHE_FILE)
                    if os.path.exists(cache_path): os.remove(cache_path)
                    draw_status(stdscr, "File removed.")
                except Exception as e: draw_status(stdscr, f"Error: {str(e)}")

def image_browser(stdscr):
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_GREEN)
    curses.curs_set(0)
    
    current_path = os.path.abspath(os.getcwd())
    selection, start_index, show_hidden = 0, 0, False
    conn_info = get_connection_info()
    needs_refresh = True
    entries = []

    while True:
        if needs_refresh:
            try:
                items = os.listdir(current_path)
                if not show_hidden: items = [i for i in items if not i.startswith('.')]
                dirs = sorted([d for d in items if os.path.isdir(os.path.join(current_path, d))], key=str.lower)
                files = sorted([f for f in items if not os.path.isdir(os.path.join(current_path, f))], key=str.lower)
                entries = ([".."] if current_path != "/" else []) + dirs + files
            except: entries = [".. [Error]"]
            needs_refresh = False

        stdscr.clear(); h, w = stdscr.getmaxyx()
        if selection >= len(entries): selection = max(0, len(entries)-1)
        if selection < start_index: start_index = selection
        elif selection >= start_index + (h-2): start_index = selection - (h-2) + 1
        
        stdscr.addstr(0, 0, f" {conn_info} | {current_path} ".ljust(w-1)[:w-1], curses.color_pair(2))
        for i, entry in enumerate(entries[start_index : start_index + (h-2)]):
            idx = i + start_index
            style = curses.color_pair(2) if idx == selection else curses.color_pair(1)
            is_dir = os.path.isdir(os.path.join(current_path, entry)) or entry == ".."
            label = f"[ {entry} ]" if is_dir else f"  {entry}"
            stdscr.addstr(i + 1, 0, f"{'> ' if idx == selection else '  '}{label}"[:w-1].ljust(w-1)[:w-1], style)

        stdscr.addstr(h-1, 0, f" [4] Hidden [q] Quit | {VERSION} ".ljust(w-1), curses.color_pair(2))
        stdscr.refresh()
        
        key = stdscr.getch()
        char = chr(key).lower() if 0 <= key < 256 else ""
        
        if key == ord('q'): break
        elif key in [curses.KEY_UP, ord('k')]: selection = (selection - 1) % len(entries)
        elif key in [curses.KEY_DOWN, ord('j')]: selection = (selection + 1) % len(entries)
        elif char == 'h' and current_path != "/":
            current_path = os.path.dirname(current_path); selection = 0; needs_refresh = True
        elif char == 'l':
            target = os.path.join(current_path, entries[selection])
            if os.path.isdir(target):
                current_path = target; selection = 0; needs_refresh = True
            elif entries[selection] == "..":
                current_path = os.path.dirname(current_path); selection = 0; needs_refresh = True
        elif key in [10, 13]: # ENTER
            target = os.path.join(current_path, entries[selection])
            if os.path.isdir(target) and entries[selection] != "..":
                choice = draw_multi_popup(stdscr, "Image Folder Action:", ["[s] Scan for Duplicates", "[c] Cancel"])
                if choice == 's':
                    results = find_duplicates(stdscr, target)
                    review_duplicates(stdscr, results, target)
                    needs_refresh = True
            elif entries[selection] == "..":
                current_path = os.path.dirname(current_path); selection = 0; needs_refresh = True
        elif char == '4':
            show_hidden = not show_hidden; needs_refresh = True

if __name__ == "__main__":
    if "-v" in sys.argv or "--version" in sys.argv:
        print(f"dupImgBrowser {VERSION}"); sys.exit(0)
    curses.wrapper(image_browser)

# VERSION: v.0.2.12

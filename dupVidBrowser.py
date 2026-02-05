#!/usr/bin/env python3
# VERSION: v.0.3.14

import os
import curses
import subprocess
import shutil
import socket
import time
import sys
import argparse
import multiprocessing

# --- Metadata ---
# Version: 0.3.14
# Fixes: removed tmpfs logic (writes directly to dir).
# Fixes: corrected vid_dup_finder CLI arguments (uses redirection > for output).
# Retains: VIM navigation fixes and thread limiting.

VERSION = "v.0.3.14"
VIDEO_EXTS = ('.mp4', '.mkv', '.avi', '.mov', '.flv', '.wmv', '.m4v', '.mpg', '.mpeg')
TEXT_EXTS = ('.txt', '.py', '.sh', '.conf', '.json', '.md', '.log', '.csv', '.bash_aliases', '.yaml', '.yml')

def get_optimal_threads():
    """Returns a safe number of threads for your 3420 Desktop or Laptop."""
    cores = os.cpu_count() or 1
    return str(max(1, cores - 2)) if cores > 2 else "1"

def get_connection_info():
    ssh_conn = os.environ.get("SSH_CONNECTION", "")
    is_ssh = bool(ssh_conn)
    hostname = socket.gethostname()
    user = os.environ.get("USER", "user")
    is_detached = "STY" in os.environ or "TMUX" in os.environ
    session_label = " (SCREEN/TMUX)" if is_detached else ""
    
    if is_ssh:
        parts = ssh_conn.split(' ')
        return f"[ REMOTE{session_label}: {user}@{hostname} ]", parts[0], parts[2], user
    return f"[ LOCAL{session_label} ]", None, "localhost", user

# --- UI Helpers ---

def draw_splash(stdscr):
    stdscr.clear()
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    h, w = stdscr.getmaxyx()
    title, ver_text = "DUP VID BROWSER", f"Version {VERSION}"
    box_w, box_h = max(len(title), len(ver_text)) + 8, 5
    start_y, start_x = (h // 2) - (box_h // 2), (w // 2) - (box_w // 2)
    stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
    stdscr.addstr(start_y, start_x, "+" + "-" * (box_w - 2) + "+")
    for i in range(1, 4): stdscr.addstr(start_y + i, start_x, "|" + " " * (box_w - 2) + "|")
    stdscr.addstr(start_y + 4, start_x, "+" + "-" * (box_w - 2) + "+")
    stdscr.addstr(start_y + 1, start_x + (box_w - len(title)) // 2, title)
    stdscr.addstr(start_y + 3, start_x + (box_w - len(ver_text)) // 2, ver_text)
    stdscr.refresh()
    time.sleep(1)

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
    win = curses.newwin(len(options) + 4, 50, h//2 - 3, w//2 - 25)
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

# --- Review & Navigation Logic ---

def review_duplicates(stdscr, filepath, base_dir):
    if not os.path.exists(filepath) or os.path.getsize(filepath) == 0:
        draw_status(stdscr, "No valid duplicates file to review."); return
    curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_CYAN)
    
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f: 
        lines = [line.rstrip() for line in f.readlines()]
    
    selectable_indices = [i for i, line in enumerate(lines) if line.strip() and not line.strip().startswith("---")]
    if not selectable_indices: 
        draw_status(stdscr, "Scan file is empty or invalid.")
        return

    sel_idx, start_index = 0, 0
    base_dir_abs = os.path.abspath(base_dir).rstrip('/') + '/'
    
    while True:
        stdscr.clear(); h, w = stdscr.getmaxyx()
        current_selection = selectable_indices[sel_idx]
        if current_selection < start_index: start_index = current_selection
        elif current_selection >= start_index + (h-2): start_index = current_selection - (h-2) + 1
        
        stdscr.addstr(0, 0, f" Reviewing: {os.path.basename(filepath)} ".ljust(w-1)[:w-1], curses.color_pair(2))
        for i in range(h-2):
            idx = i + start_index
            if idx >= len(lines): break
            content = lines[idx]
            is_selected = (idx == current_selection)
            prefix = "> " if is_selected else "  "; full_line = f"{prefix}{content}"
            if not content.strip(): stdscr.addstr(i + 1, 0, " " * (w-1), curses.color_pair(1))
            elif content.startswith(base_dir_abs):
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
        if ch in [ord('q'), 27]: break
        elif ch in [curses.KEY_UP, ord('k')]: sel_idx = (sel_idx - 1) % len(selectable_indices)
        elif ch in [curses.KEY_DOWN, ord('j')]: sel_idx = (sel_idx + 1) % len(selectable_indices)
        elif char == 'h': break 
        elif ch in [10, 13, ord('l')]: 
            curr = lines[current_selection].strip()
            choice = draw_multi_popup(stdscr, "Action:", ["[v] Play", "[d] Delete", "[c] Cancel"])
            if choice == 'v':
                conn_info, client_ip, server_ip, user = get_connection_info()
                if client_ip:
                    sftp_url = f"sftp://{user}@{server_ip}{os.path.abspath(curr)}"
                    subprocess.run(['ssh', '-f', client_ip, f"export DISPLAY=:0; vlc \"{sftp_url}\" > /dev/null 2>&1 &"])
                else: subprocess.run(['vlc', curr], stderr=subprocess.DEVNULL)
            elif choice == 'd' and draw_popup_confirm(stdscr, f"Delete: {os.path.basename(curr)}?"):
                try: os.remove(curr); lines[current_selection] = f"--- DELETED: {curr} ---"; draw_status(stdscr, "Deleted.")
                except Exception as e: draw_status(stdscr, f"Error: {str(e)}")

def handle_file_open(stdscr, path, client_ip, server_ip, user):
    ext = os.path.splitext(path)[1].lower()
    if ext in VIDEO_EXTS:
        if draw_multi_popup(stdscr, "Video Action:", ["[v] Play in VLC", "[c] Cancel"]) == 'v':
            if client_ip:
                sftp_url = f"sftp://{user}@{server_ip}{os.path.abspath(path)}"
                subprocess.run(['ssh', '-f', client_ip, f"export DISPLAY=:0; vlc \"{sftp_url}\" > /dev/null 2>&1 &"])
            else: subprocess.run(['vlc', path], stderr=subprocess.DEVNULL)
    elif ext in TEXT_EXTS or not ext:
        if draw_multi_popup(stdscr, "Text Action:", ["[v] View in Vim", "[c] Cancel"]) == 'v':
            curses.def_prog_mode(); curses.endwin(); subprocess.run(['vim', path]); curses.reset_prog_mode(); curses.curs_set(0); stdscr.refresh()
    else: subprocess.run(['xdg-open', path], stderr=subprocess.DEVNULL)

def file_browser(stdscr):
    draw_splash(stdscr)
    conn_info, client_ip, server_ip, user = get_connection_info()
    curses.start_color(); curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK); curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_GREEN); curses.curs_set(0)
    
    current_path = os.path.abspath(os.getcwd())
    history, selection, start_index, show_hidden = [], 0, 0, False
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
            idx = i + start_index; style = curses.color_pair(2) if idx == selection else curses.color_pair(1)
            is_dir = os.path.isdir(os.path.join(current_path, entry)) or entry == ".."
            label = f"[ {entry} ]" if is_dir else f"  {entry}"
            stdscr.addstr(i + 1, 0, f"{'> ' if idx == selection else '  '}{label}"[:w-1].ljust(w-1)[:w-1], style)
        
        footer = f" [g]GoTo [f]Find [4]Hidden [q]Quit ".ljust(w - len(f" {VERSION} ") - 1) + f" {VERSION} "
        stdscr.addstr(h-1, 0, footer[:w-1], curses.color_pair(2))
        stdscr.refresh()
        
        key = stdscr.getch()
        char = chr(key).lower() if 0 <= key < 256 else ""
        
        if key == ord('q'): break
        elif key in [curses.KEY_UP, ord('k')]: selection = (selection - 1) % len(entries)
        elif key in [curses.KEY_DOWN, ord('j')]: selection = (selection + 1) % len(entries)
        elif char == 'h':
            if current_path != "/":
                history.append(current_path); current_path = os.path.dirname(current_path); selection = 0
                needs_refresh = True
        elif char == 'l':
            target = os.path.join(current_path, entries[selection])
            if entries[selection] == "..":
                history.append(current_path); current_path = os.path.dirname(current_path); selection = 0
                needs_refresh = True
            elif os.path.isdir(target):
                history.append(current_path); current_path = target; selection = 0
                needs_refresh = True
            else:
                handle_file_open(stdscr, target, client_ip, server_ip, user)
        elif key in [10, 13]: # ENTER
            target = os.path.join(current_path, entries[selection])
            if os.path.isdir(target) and entries[selection] != "..":
                dup_file = os.path.join(target, "dups.txt") # Writing DIRECTLY to directory
                
                opts = ["[s] Scan", "[c] Cancel"]
                if os.path.exists(dup_file): opts.insert(0, "[v] View dups.txt")
                
                choice = draw_multi_popup(stdscr, "Folder Action:", opts)
                if choice == 'v':
                    review_duplicates(stdscr, dup_file, target)
                elif choice == 's':
                    threads = get_optimal_threads()
                    exe = shutil.which("vid_dup_finder") or os.path.expanduser("~/.cargo/bin/vid_dup_finder")
                    
                    curses.def_prog_mode(); curses.endwin(); os.system('clear')
                    print(f"--- SCANNING: {target} ---")
                    print(f"Using {threads} threads via RAYON_NUM_THREADS...")
                    
                    # REVERTED TO REDIRECTION '>' and removed '/tmp' usage
                    scan_cmd = f'RAYON_NUM_THREADS={threads} {exe} --output dups --files "{target}" > "{dup_file}"'
                    
                    try:
                        # Removed check=True to prevent crash if tool exits with warnings
                        # Using shell redirection requires shell=True
                        subprocess.run(scan_cmd, shell=True) 
                        
                        if os.path.exists(dup_file) and os.path.getsize(dup_file) > 0:
                            print("\nScan complete. Returning to browser...")
                        else:
                            print(f"\nScan finished, but '{dup_file}' is empty or missing.")
                            time.sleep(1.5)
                    except Exception as e:
                        print(f"\nExecution Error: {e}")
                        time.sleep(3)
                    
                    curses.reset_prog_mode(); curses.curs_set(0); stdscr.refresh()
                    if os.path.exists(dup_file):
                        review_duplicates(stdscr, dup_file, target)
            elif entries[selection] == "..":
                history.append(current_path); current_path = os.path.dirname(current_path); selection = 0; needs_refresh = True
            else:
                handle_file_open(stdscr, target, client_ip, server_ip, user)
        elif char == '4':
            show_hidden = not show_hidden; needs_refresh = True
        elif char == 'g':
            from sys import path as pythonpath
            res = draw_goto_menu(stdscr, len(history) > 0)
            if res == "BACK": current_path = history.pop(); selection = 0; needs_refresh = True
            elif res: history.append(current_path); current_path = res; selection = 0; needs_refresh = True

def draw_goto_menu(stdscr, has_history):
    bookmarks = [("1", "Home", os.path.expanduser("~")), ("2", "Docs", os.path.expanduser("~/Documents")), 
                 ("3", "Downloads", os.path.expanduser("~/Downloads")), ("4", "Root", "/")]
    if has_history: bookmarks.append(("b", "Go Back", "BACK"))
    bookmarks.append(("c", "Cancel", None))
    h, w = stdscr.getmaxyx(); win_h = len(bookmarks) + 4
    win = curses.newwin(win_h, 35, h//2 - win_h//2, w//2 - 17)
    win.attron(curses.color_pair(1)); win.box(); win.addstr(1, 2, " Go To: ", curses.A_BOLD)
    for i, (key, label, _) in enumerate(bookmarks): win.addstr(i + 2, 2, f"[{key}] {label}")
    win.refresh()
    while True:
        ch = win.getch(); char = chr(ch).lower() if 0 <= ch < 256 else ""
        for key, _, path in bookmarks:
            if char == key: return path
        if ch == 27: return None

if __name__ == "__main__":
    if "-v" in sys.argv or "--version" in sys.argv:
        print(f"dupVidBrowser {VERSION}"); sys.exit(0)
    curses.wrapper(file_browser)

# VERSION: v.0.3.14

#!/usr/bin/env python3

import time
import tkinter as tk
from tkinter import messagebox

# Version 00.01.00
#this is a python script that delivers a graphical user interface to help the user with anxiety through breathing methods. It asked the user for how many cycles of the breathing process it would like to run. Then for each number of cycles the script tells the user to take a deep breath in for five seconds, then hold it for five seconds, then let it out for five seconds and then proceeds to the next cycle

# Function to display the breathing phase and countdown
def display_phase(phase, seconds, label, color):
    for i in range(seconds, 0, -1):
        label.config(text=f"{phase}\n\n{i}", fg=color)
        root.update()
        time.sleep(1)

# Function to start the breathing exercise
def start_breathing():
    try:
        cycles = int(cycles_entry.get())
        if cycles <= 0:
            raise ValueError("Number of cycles must be greater than 0.")
    except ValueError:
        messagebox.showerror("Invalid Input", "Please enter a valid positive integer for cycles.")
        return

    # Remove input widgets after getting the number of cycles
    instructions.pack_forget()
    cycles_entry.pack_forget()
    start_button.pack_forget()

    # Start the breathing exercise
    for cycle in range(1, cycles + 1):
        display_phase("Inhale", 5, phase_label, "#ADD8E6")  # Light Blue
        display_phase("Hold", 5, phase_label, "#FFFFE0")    # Light Yellow
        display_phase("Exhale", 5, phase_label, "#90EE90")  # Light Green

        # Pause before the next cycle
        phase_label.config(text=f"Cycle {cycle} completed.\n\nPrepare for the next cycle...", fg="#FFFFFF")
        root.update()
        time.sleep(2)

    phase_label.config(text="Breathing exercise completed.\n\nWell done!", fg="#FFFFFF")

# Create the GUI application
root = tk.Tk()
root.title("Calm Breathing Exercise")

# Set window size and center it on the screen
window_width = 400
window_height = 300
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
position_top = int(screen_height / 2 - window_height / 2)
position_right = int(screen_width / 2 - window_width / 2)
root.geometry(f'{window_width}x{window_height}+{position_right}+{position_top}')

# Set a soothing background color
root.configure(bg="#2E4053")  # Calming dark blue

# Instructions label
instructions = tk.Label(root, text="Enter the number of breathing cycles and press Start:", font=("Helvetica", 12), bg="#2E4053", fg="#FFFFFF")
instructions.pack(pady=20)

# Entry for the number of cycles
cycles_entry = tk.Entry(root, width=10, font=("Helvetica", 12))
cycles_entry.pack(pady=10)

# Button to start the exercise
start_button = tk.Button(root, text="Start", command=start_breathing, font=("Helvetica", 12), bg="#5DADE2", fg="#FFFFFF", activebackground="#3498DB", activeforeground="#FFFFFF")
start_button.pack(pady=20)

# Label to display the current phase and countdown
phase_label = tk.Label(root, text="", font=("Helvetica", 24), bg="#2E4053", fg="#FFFFFF")
phase_label.pack(pady=30)

# Run the application
root.mainloop()


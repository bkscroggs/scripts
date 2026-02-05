#!/bin/bash

#Version 0.1.00
#this is a bash script, used with the command line interface to help the user deal with an acute anxiety attack

# Check if Zenity is installed
if ! command -v zenity &> /dev/null
then
    echo "Zenity is required but not installed. Please install Zenity and run the script again. Run: sudo nala install zenity"
    exit 1
fi

# Welcome message
zenity --info --title="Grounding Tool" --text="Welcome to the Grounding and Catastrophizing Management Tool\n\nLet's walk through some steps to help you regain control. Click OK to begin."

# Step 1: Challenge Your Thoughts
worst_case=$(zenity --entry --title="Step 1: Challenge Your Thoughts" --text="Write down the worst-case scenario you're imagining:")

evidence=$(zenity --entry --title="Step 1: Challenge Your Thoughts" --text="What evidence supports this fear?")

balanced_outcome=$(zenity --entry --title="Step 1: Challenge Your Thoughts" --text="What's a more likely or balanced outcome?")

# Step 2: Shift Your Perspective
advice_to_friend=$(zenity --entry --title="Step 2: Shift Your Perspective" --text="Imagine a friend came to you with the same problem. What advice would you give them?")

long_term_perspective=$(zenity --entry --title="Step 2: Shift Your Perspective" --text="Zoom out for a moment: Will this matter in a week, a month, or a year?")

# Step 3: Grounding Techniques
see=$(zenity --entry --title="Step 3: Grounding Techniques" --text="Name 5 things you see:")

touch=$(zenity --entry --title="Step 3: Grounding Techniques" --text="Name 4 things you can touch:")

hear=$(zenity --entry --title="Step 3: Grounding Techniques" --text="Name 3 things you hear:")

smell=$(zenity --entry --title="Step 3: Grounding Techniques" --text="Name 2 things you smell:")

taste=$(zenity --entry --title="Step 3: Grounding Techniques" --text="Name 1 thing you taste:")

zenity --info --title="Step 3: Grounding Techniques" --text="Great work! Now take a moment to breathe deeply. Inhale for 4 seconds, hold for 4 seconds, exhale for 4 seconds. Repeat this a few times before moving on." --timeout=10

# Step 4: Practice Acceptance
control_now=$(zenity --entry --title="Step 4: Practice Acceptance" --text="Say to yourself: 'I’m having a catastrophic thought. It doesn’t mean it’s true.'\n\nFocus on what you can control right now. Write down one thing you can control at this moment:")

# Step 5: Redirect Your Energy
activity=$(zenity --entry --title="Step 5: Redirect Your Energy" --text="Engage in a quick activity to distract and center yourself.\n\nSome examples: Go for a walk, do a chore, or listen to music. What activity will you do?")

# Closing
summary="You've completed the grounding exercise!\n\nHere’s a summary of your responses:\n\n"
summary+="Worst-case scenario: $worst_case\n"
summary+="Evidence for this fear: $evidence\n"
summary+="Balanced outcome: $balanced_outcome\n"
summary+="Advice to a friend: $advice_to_friend\n"
summary+="Long-term perspective: $long_term_perspective\n"
summary+="5 things you see: $see\n"
summary+="4 things you can touch: $touch\n"
summary+="3 things you hear: $hear\n"
summary+="2 things you smell: $smell\n"
summary+="1 thing you taste: $taste\n"
summary+="What you can control: $control_now\n"
summary+="Chosen activity: $activity\n\n"
summary+="Remember, you’ve got this! Take things one step at a time."

zenity --info --title="Summary" --text="$summary"
exit 0


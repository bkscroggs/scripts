#!/bin/bash

# Fetch a random dad joke from the icanhazdadjoke.com API
joke=$(curl -s -H "Accept: text/plain" https://icanhazdadjoke.com/)

# Check if the API request was successful
if [[ $? -eq 0 ]]; then
    echo "$joke"
else
    echo "Oops! I couldn't fetch a dad joke. Maybe try again later?"
fi


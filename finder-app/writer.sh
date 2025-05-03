#!/bin/sh

# Check if both arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Error: Two arguments required - path to the file and text string to write."
    exit 1
fi

# Assign arguments to variables
writefile=$1
writestr=$2

# Extract the directory path from the full file path
writedir=$(dirname "$writefile")

# Create the directory if it does not exist
if [ ! -d "$writedir" ]; then
    mkdir -p "$writedir"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create directory $writedir."
        exit 1
    fi
fi

# Write the string to the file, overwriting if it exists
echo "$writestr" > "$writefile"
if [ $? -ne 0 ]; then
    echo "Error: Could not write to file $writefile."
    exit 1
fi

echo "Successfully wrote to $writefile"
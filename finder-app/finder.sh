#!/bin/sh

# Check if both arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Error: Two arguments required - path to the directory and search string."
    exit 1
fi

# Assign arguments to variables
filesdir=$1
searchstr=$2

# Check if the first argument is a directory
if [ ! -d "$filesdir" ]; then
    echo "Error: The specified path ($filesdir) is not a directory."
    exit 1
fi

# Initialize counters
file_count=0
matching_lines_count=0

# Iterate over each file and subdirectory in the specified directory
for file in $(find "$filesdir" -type f); do
    # Increment file count
    file_count=$((file_count + 1))
    # Count matching lines containing the search string
    matches_in_file=$(grep -c "$searchstr" "$file")
    matching_lines_count=$((matching_lines_count + matches_in_file))
done

# Print the result
echo "The number of files are $file_count and the number of matching lines are $matching_lines_count"
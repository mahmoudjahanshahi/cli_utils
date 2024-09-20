#!/bin/bash

# Function to display usage for sort_merge
usage() {
    echo "Usage: $0 [-t total_files] [-f first_index] [-s step_size] [sort_options] filename"
    echo "  filename      : The base name of the files to merge."
    echo "  -t total_files: The total number of files to merge (default: 128)."
    echo "  -f first_index: The first index of the files (default: 0)."
    echo "  -s step_size  : The step size for indexing files (default: 1)."
    echo "  -H            : Display this help message."
    exit 1
}

# Default values
first_index=0
total_files=128
step_size=1

# Parse options
while getopts "t:f:s:H" opt; do
    case $opt in
        t) total_files="$OPTARG" ;;    # -t for total number of files
        f) first_index="$OPTARG" ;;    # -f for first index
        s) step_size="$OPTARG" ;;      # -s for step size
        H) usage ;;                    # -H to display help
        *) usage ;;                    # Invalid option
    esac
done
shift $((OPTIND - 1))  # Shift processed options

# Check if filename is provided
filename=$1
if [[ -z "$filename" ]]; then
    echo "Error: Filename is required."
    usage
fi

# Calculate the last index based on first index and total number of files
last_index=$((first_index + (total_files - 1) * step_size))

# Construct the sort command
cmd="$HOME/utils/sort.sh -t\; -m -u"

# Loop through files and add them to the command using step size
for ((i = first_index; i <= last_index; i += step_size)); do
    f="$filename.$i"
    cmd="$cmd <(zcat $f)"
done

# Execute the command
eval "$cmd"

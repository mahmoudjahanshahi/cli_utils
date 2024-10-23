#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 filename [-t total_files] [-f first_index] [-s step_size] [sort_options]"
    echo "  filename      : The base name of the files to merge."
    echo "  -t total_files: The total number of files to merge (default: 128)."
    echo "  -f first_index: The first index of the files (default: 0)."
    echo "  -s step_size  : The step size for indexing files (default: 1)."
    exit 1
}

# Check if filename is provided
if [[ -z "$1" ]]; then
    usage
fi

# Set the name from the first positional argument
filename=$1
shift

# Default values
first_index=0
total_files=128
step_size=1

# Parse options
while getopts ":t:f:s:" opt; do
    case $opt in
        t) total_files="$OPTARG" ;; 
        f) first_index="$OPTARG" ;;
        s) step_size="$OPTARG" ;;
        *) usage ;;
    esac
done

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

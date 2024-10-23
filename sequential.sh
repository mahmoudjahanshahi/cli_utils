#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 filename merge_command process_command [-t total_files] [-f first_index] [-s step_size]"
    echo "  filename        : The base name of the files."
    echo "  merge_command   : Command to merge files."
    echo "  process_command : Command to process after merging files (can include pipes)."
    echo "  -t total_files  : The total number of files (must be greater than 2, default: 128)."
    echo "  -f first_index  : The first index of the files (default: 0)."
    echo "  -s step_size    : The step size for indexing files (default: 1)."
    exit 1
}

# Validate input
if [ -z "$1" ] || [ -z "$2" ]; then
    usage
fi

# Set the file prefix and command
file_prefix="$1"
merge_command="$2"
process_command="$3"
shift 3

# Default values
start=0
total=128
step=1

# Parse options
while getopts ":t:f:s:" opt; do
    case $opt in
        f) start="$OPTARG" ;;
        t) total="$OPTARG" ;;
        s) step="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ total -lt 3 ]]; then
    usage
fi

# Recursive function to process files
recursive() {
    if [ $# -eq 1 ]; then
        eval "$merge_command - <(zcat \"$1\")" | 
        eval "$process_command"
    else
        f=$1
        shift
        eval "$merge_command - <(zcat \"$f\")" | 
        eval "$process_command" | 
        recursive "$@"
    fi
}

# Prepare file list based on start, total, and step values
files_list=""
for (( i = start; i < start + total; i += step )); do
    files_list+="${file_prefix}.${i} "
done

# Start the process by joining the first two files and passing the rest to recJoin
first_file=$(echo $files_list | awk '{print $1}')
second_file=$(echo $files_list | awk '{print $2}')
remaining_files=$(echo $files_list | cut -d' ' -f3-)

eval "$merge_command <(zcat \"$first_file\") <(zcat \"$second_file\")" | 
eval "$process_command" |
recursive $remaining_files

#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 filename [-t total_files] [-f first_index] [-s step_size] [-m mode]"
    echo "  filename      : The base name of the files to merge."
    echo "  -t total_files: The total number of files to merge (default: 128)."
    echo "  -f first_index: The first index of the files (default: 0)."
    echo "  -s step_size  : The step size for indexing files (default: 1)."
    echo "  -m mode   : Mode of operation (r: check results, d: delete files, default: r)"
    echo "  -H            : Display this help message."
    exit 1
}

# Check if the first argument is present
if [[ -z "$1" ]]; then
    usage
fi

# Set the name from the first positional argument
name="$1"
shift # Shift arguments so that getopts can handle the remaining options

# Default values
start=0
total=128
step=1
mode="r"

# Parse command-line options
while getopts ":f:t:s:m:" opt; do
    case $opt in
        f) start="$OPTARG" ;;
        t) total="$OPTARG" ;;
        s) step="$OPTARG" ;;
        m) mode="$OPTARG" ;;
        *) usage ;;
    esac
done

# Variable calculations
finish=$((start + total))

# Mode 'r': Check results
if [[ "$mode" == "r" ]]; then
    # Initialize counters for average time calculation
    total_time=0
    completed_steps=0
    errors_found=0

    # 1. Check for errors and 2. Missing files
    for ((i=start; i<finish; i+=step)); do
        # Define the expected output and error files
        output_file=$(ls "${name}.${i}".o* 2>/dev/null)
        error_file=$(ls "${name}.${i}".e* 2>/dev/null)
        steps_in_file_start=$i
        steps_in_file_end=$((i + step - 1))

        # Check if the output and error files exist
        if [[ -n "$output_file" ]] && [[ -e "$output_file" ]]; then
            # If the error file exists and is not empty, there was an error
            if [[ -n "$error_file" ]] && [[ -s "$error_file" ]]; then
                echo "Error found in file: $error_file"
                errors_found=$((errors_found + 1))
            else
                # Initialize an associative array to track steps
                declare -A step_tracker
                for ((j=steps_in_file_start; j<=steps_in_file_end; j++)); do
                    step_tracker[$j]=0
                done

                # Check if the process has finished by looking for the "finished" message in the output file
                while IFS= read -r line; do
                    # Extract the step number from the "finished" line
                    if [[ $line =~ finished\ ([0-9]+) ]]; then
                        step_number=${BASH_REMATCH[1]}
                        if (( step_number >= steps_in_file_start && step_number <= steps_in_file_end )); then
                            step_tracker[$step_number]=$((step_tracker[$step_number] + 1))
                            
                            # Extract the hours and minutes using a regular expression
                            if [[ $line =~ ([0-9]+)\ hours\ and\ ([0-9]+)\ minutes ]]; then
                                hours=${BASH_REMATCH[1]}
                                minutes=${BASH_REMATCH[2]}
                                seconds=$((hours * 3600 + minutes * 60))

                                # Add to total time and increment completed steps counter
                                total_time=$((total_time + seconds))
                                completed_steps=$((completed_steps + 1))
                            fi
                        else
                            echo "Mismatch in file number for: $output_file. Found unexpected file $step_number."
                            errors_found=$((errors_found + 1))
                        fi
                    fi
                done < <(grep "finished" "$output_file")

                # Check for missing or duplicated steps
                for ((j=steps_in_file_start; j<=steps_in_file_end; j++)); do
                    if [[ "${step_tracker[$j]}" -eq 0 ]]; then
                        echo "File $j is missing in: $output_file"
                        errors_found=$((errors_found + 1))
                    elif [[ "${step_tracker[$j]}" -gt 1 ]]; then
                        echo "File $j is duplicated in: $output_file"
                        errors_found=$((errors_found + 1))
                    fi
                done
            fi
        else
            echo "Output file missing for: $name.$i"
            errors_found=$((errors_found + 1))
        fi
    done

    # 3. Calculate average processing time
    if [[ $completed_steps -gt 0 && $errors_found -eq 0 ]]; then
        average_time=$((total_time / completed_steps))
        hours=$((average_time / 3600))
        minutes=$(( (average_time % 3600) / 60 ))
        seconds=$((average_time % 60))
        echo "Total files finished: $completed_steps"
        echo "No errors were found."
        echo "Average processing time per file: ${hours} hours, ${minutes} minutes, and ${seconds} seconds"
    elif [[ $errors_found -gt 0 ]]; then
        echo "$errors_found error(s) were found during processing. Please review the log."
    else
        echo "No finished files found."
    fi

# Mode 'd': Delete output, error, and slurm files
elif [[ "$mode" == "d" ]]; then
    read -p "Are you sure you want to delete the output, error, and slurm files? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        for ((i=start; i<finish; i+=step)); do
            # Define the files to delete
            output_file=$(ls "${name}.${i}".o* 2>/dev/null)
            error_file=$(ls "${name}.${i}".e* 2>/dev/null)
            slurm_file="${name}.${i}.slurm"

            # Remove the files
            rm -f "$output_file"
            rm -f "$error_file"
            rm -f "$slurm_file"
        done
        echo "Files deleted."
    else
        echo "Deletion canceled."
    fi

else
    echo "Invalid mode selected."
    usage
fi

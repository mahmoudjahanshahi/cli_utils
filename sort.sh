#!/bin/bash

# Export the environment variables for consistent sorting
export LC_ALL=C 
export LANG=C  

# Ensure the ./tmp/ directory exists
if [[ ! -d "./tmp" ]]; then
    mkdir -p "./tmp"
fi

# Execute the sort command with any additional options and files
sort -T ./tmp/ "$@"

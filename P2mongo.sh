#!/bin/bash

# P2mongo.sh - A script to fetch project metadata from WoC MongoDB and process it.
#
# Usage:
#   1. Fetch data from MongoDB and automatically parse it:
#      echo "ProjectID" | ./P2mongo.sh -o output.json
#
#   2. Fetch data but skip parsing:
#      echo "ProjectID" | ./P2mongo.sh -o output.json --skip-parse
#
#   3. Parse an existing JSON file (skip MongoDB fetching):
#      ./P2mongo.sh -i output.json.gz
#
# Options:
#   -o <filepath>    Fetch data from MongoDB and save it to <filepath>.gz
#   -i <filepath>    Parse an existing compressed JSON file
#   --skip-parse     Fetch data but do not immediately parse it
#
# Behavior:
#   - If '-o' is provided, the script queries MongoDB for project metadata,
#     saves it in <filepath>.gz, and processes it (unless --skip-parse is used).
#   - If '-i' is provided, the script skips MongoDB and parses the given file.
#   - The script prevents using '-o' and '-i' together to avoid conflicts.
#
# Requirements:
#   - MongoDB access via pymongo
#   - jq, awk, lsort, gzip for processing


OUTPUT_FILE=""
INPUT_FILE=""
SKIP_PARSE=false

# Function to fetch MongoDB data
fetch() {
    if [ -z "$OUTPUT_FILE" ]; then
        echo "Error: Output file not specified. Use -o <filepath>" >&2
        exit 1
    fi

    # Check if the file already exists
    if [ -f "$OUTPUT_FILE.gz" ]; then
        read -p "File $OUTPUT_FILE.gz already exists. Do you want to overwrite it? (y/n): " choice
        case "$choice" in 
            y|Y ) echo "Overwriting $OUTPUT_FILE.gz...";;
            n|N ) echo "Operation cancelled."; exit 0;;
            * ) echo "Invalid input. Operation cancelled."; exit 1;;
        esac
    fi

    python3 -uc '
import sys
from pymongo import MongoClient
from bson.json_util import dumps

try:
    client = MongoClient("mongodb://da1.eecs.utk.edu/", serverSelectionTimeoutMS=5000)
    db = client["WoC"]
    coll = db["P_metadata.V"]
    client.server_info()  # Force connection test
except Exception as e:
    print(f"Error connecting to MongoDB: {e}", file=sys.stderr)
    sys.exit(1)

projects = sys.stdin.read().splitlines()
with open("'"$OUTPUT_FILE"'", "w") as f:
    for p in projects:
        c = coll.find({"ProjectID": p})
        for r in c:
            json = dumps(r)
            f.write(json + "\n")
' && gzip -f "$OUTPUT_FILE"

    echo "MongoDB query completed. Data stored in $OUTPUT_FILE.gz"
}

# Function to process the specified output file
parse() {
    if [ -z "$INPUT_FILE" ]; then
        echo "Error: No input file provided. Use -i <file>"
        exit 1
    fi

    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: File $INPUT_FILE not found!" >&2
        exit 1
    fi

    zcat "$INPUT_FILE" |
    jq -r '"\(.ProjectID);\(.EarliestCommitDate);\(.LatestCommitDate);\(.NumActiveMon);\(.NumAuthors);\(.NumCore);\(.Gender.male);\(.Gender.female);\(.CommunitySize);\(.NumForks);\(.NumCommits);\(.NumFiles);\(.NumBlobs);\(.NumStars)"' | 
    ~/utils/sort.sh -t\; -u |
    awk -F\; '{
        OFS=";"
        for (i=7; i<=NF; i++) {
            if ($i == "null") {
                $i=0
            }
        }
        print
    }' |
    ~/utils/sort.sh -t\; -u |
    gzip >tempfile1.gz

    zcat "$INPUT_FILE" |
    jq -r '.ProjectID as $p | 
        .FileInfo | try keys[] as $k | 
        "\($p);\($k);\(.[$k])"' |
    awk -F\; '
        BEGIN {
            ll=""
            m=0
            lm=""
        }
        {
            l=$1
            if (l!=ll) {
                print ll";"lm
                ll=l
                m=0
                lm=""
            }
            if ($3>m && $2!="other") {
                m=$3
                lm=$2
            }
        }
        END {
            print ll";"lm
        }
    ' |
    tail -n +2 |
    ~/utils/sort.sh -t\; -u |
    gzip >tempfile2.gz

    LC_ALL=C LANG=C join -t\; -a1 \
        <(zcat tempfile1.gz | ~/utils/sort.sh -t\; -k1,1) \
        <(zcat tempfile2.gz | ~/utils/sort.sh -t\; -k1,1) |
    awk -F\; '{OFS=";";if ($15=="") {$15="other"}; print}' |
    ~/utils/sort.sh -t\; -u 

    rm tempfile{1,2}.gz
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o) OUTPUT_FILE="$2"; shift ;;
        -i) INPUT_FILE="$2"; shift ;;
        --skip-parse) SKIP_PARSE=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Ensure valid argument combinations
if [ -n "$OUTPUT_FILE" ] && [ -n "$INPUT_FILE" ]; then
    echo "Error: You cannot use both -o and -i at the same time."
    exit 1
elif [ -n "$OUTPUT_FILE" ]; then
    # Ensure input is provided through a pipe for fetching
    if [ -t 0 ]; then
        echo "Usage: echo <ProjectID> | ./P2mongo.sh -o <filepath> [--skip-parse]"
        exit 1
    fi
    fetch
    if [ "$SKIP_PARSE" = false ]; then
        INPUT_FILE="$OUTPUT_FILE.gz"
        parse
    else
        echo "Skipping parse processing."
    fi
elif [ -n "$INPUT_FILE" ]; then
    parse
else
    echo "Usage:"
    echo "  ./P2mongo.sh -o <filepath> [--skip-parse]  # Fetch data from MongoDB"
    echo "  ./P2mongo.sh -i <file>                     # Parse an existing JSON file"
    exit 1
fi

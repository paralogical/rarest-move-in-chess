#!/bin/sh
# Runs collect script on a given input file, and moves the output to a specific folder
# `zig build run -- collect` reads from stdin and writes json to stdout
# but we want to use a file name as the output and redirect to a subfolder.
# This script makes this process a bit smoother, while keeping the zig command simple.
# results are written to `partialResults/$1.result.json`
# This is also parallelizable by running multiple instances of this script,
# again without complicating the zig code.

# Usage: collect.sh <input file>

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input file>"
    exit 1
fi

# Make short name without extension
shortName=$(basename $1 .pgn.zst)

echo "Building executable"
zig build -Doptimize=ReleaseFast

# Print filename
echo "Collecting from $1 into partialResults/$shortName.result.json"

# Decompress and pipe into collection
zstdcat $1 | ./zig-out/bin/chesspgn collect > partialResults/$shortName.result.json

# Error if something went wrong
if [ $? -ne 0 ]; then
    echo "Error while collecting from $1"
    exit 1
fi

echo "Results written to partialResults/$shortName.result.json"


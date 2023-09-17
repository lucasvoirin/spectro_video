#!/bin/bash

# Check if the argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 input.wav"  # Provide usage message if argument count is incorrect
    exit 1  # Exit script with error status
fi

input_file=$1

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File $input_file not found."  # Provide error message for missing file
    echo "Please make sure the file exists and try again."
    exit 1  # Exit script with error status
fi

file_name=$(basename "$input_file" .wav)  # Extract base name without extension

mkdir "$file_name-temp"  # Create a temporary directory

cp $input_file "$file_name-temp"  # Copy input file to temporary directory

cd "$file_name-temp"  # Move into the temporary directory

# Check if the input file is stereo and extract first channel if necessary
sox input.wav -n channels && sox input.wav mono.wav remix 1

# Add 2.5 seconds of silence before and after
sox -n silence.wav trim 0.0 2.5
sox mono.wav silence.wav mono_silence.wav
sox silence.wav mono_silence.wav silence_mono_silence.wav

# Create frames directory if it doesn't exist
mkdir -p frames

# Get total duration in seconds and convert to integer
total_duration=$(soxi -D mono.wav | cut -d '.' -f 1)

# Determine total number of frames needed
frame_rate=50
frame_count=$((frame_rate * total_duration))

# Loop through frames
for ((i=0; i<frame_count; i++)); do
    start_time=$(bc <<< "scale=5; $i / $frame_rate")

    # Generate spectrogram for the frame
    frame_file="frames/frame$(printf %03d $i).png"
    sox silence_mono_silence.wav -n trim $start_time 5 spectrogram -x 500 -y 500 -r -o "$frame_file"

    echo "$i over $frame_count"  # Print progress
done

# Use ffmpeg to create the video
ffmpeg -framerate $frame_rate -i frames/frame%03d.png -i mono.wav -vf drawbox=x=250:y=10:w=1:h=480:color=red "$file_name.mp4"

cp "$file_name.mp4" ..  # Copy the generated video to the parent directory

cd ..  # Move back to the parent directory

rm -r "$file_name-temp"  # Remove the temporary directory and its contents


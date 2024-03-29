#!/bin/bash

# Define variables
frame_rate=35
spectro_height=600
spectro_width=600

# Check if the argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: bash $0 input.wav"  # Provide usage message if argument count is incorrect
    exit 1  # Exit script with error status
fi

input_file=$1

# Check if the file extention is .wav
if [[ ! "$input_file" =~ \.wav$ ]]; then
    echo "Error: File must have .wav extension."
    exit 1
fi

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
sox $input_file -n channels && sox $input_file mono.wav remix 1

sample_rate=$(sox --i -r mono.wav)

# Add 2.5 seconds of silence before and after
sox -n -r $sample_rate silence.wav trim 0.0 2.5
sox mono.wav silence.wav mono_silence.wav
sox silence.wav mono_silence.wav silence_mono_silence.wav

# Create frames directory if it doesn't exist
mkdir -p frames

# Get total duration in seconds and convert to integer
total_duration=$(soxi -D mono.wav | cut -d '.' -f 1)

# Determine total number of frames needed
frame_count=$((frame_rate * total_duration))

# Loop through frames
for ((i=0; i<frame_count; i++)); do
    start_time=$(bc <<< "scale=5; $i / $frame_rate")

    # Generate spectrogram for the frame
    frame_file="frames/frame$(printf %03d $i).png"
    sox silence_mono_silence.wav -n trim $start_time 5 spectrogram -x $spectro_width -y $spectro_height -r -o "$frame_file"

percentage=$(( (i * 100) / frame_count + 1 ))
printf "\rProgress: %s %% " "$percentage"  # Print progress as percentage on the same line

done

echo

# Use ffmpeg to create the video
ffmpeg -framerate $frame_rate -i frames/frame%03d.png -i mono.wav -c:v libx264 -preset slow -crf 20 -c:a aac -b:a 160k -vf "drawbox=x=$((spectro_width/2)):y=10:w=1:h=$((spectro_heigt-20)):color=red,format=yuv420p" -movflags +faststart "$file_name.mp4" > /dev/null 2>&1

cp "$file_name.mp4" ..  # Copy the generated video to the parent directory

cd ..  # Move back to the parent directory

rm -r "$file_name-temp"  # Remove the temporary directory and its contents

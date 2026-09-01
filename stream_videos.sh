#!/bin/bash

# Stream videos to multiple platforms using ffmpeg and the tee muxer
stream_videos() {
    echo "Starting the streaming process..."

    # Access environment variables directly
    local VIDEO_DIR="${VIDEO_DIR}"
    local TWITCH_STREAM_KEY="${TWITCH_STREAM_KEY}"
    local YOUTUBE_API_KEY="${YOUTUBE_API_KEY}"
    local KICK_STREAM_URL="${KICK_STREAM_URL}"  # Kick stream URL
    local KICK_STREAM_KEY="${KICK_STREAM_KEY}"  # Kick stream key

    echo "Video directory: ${VIDEO_DIR}"
    echo "Twitch Stream Key: ${TWITCH_STREAM_KEY}"
    echo "YouTube API Key: ${YOUTUBE_API_KEY}"
    echo "Kick Stream URL: ${KICK_STREAM_URL}"
    echo "Kick Stream Key: ${KICK_STREAM_KEY}"

    # Loop through all MP4/MKV files sorted naturally (-V)
    find "${VIDEO_DIR}" -type f \( -iname '*.mp4' -o -iname '*.mkv' \) | sort -V | while read -r file; do
        echo "Preparing to stream file: $file"

        # Base ffmpeg command setup with escaped filters
        local FFMPEG_CMD="ffmpeg -thread_queue_size 8124 -analyzeduration 10M -probesize 10M -re -nostdin -i \"$file\" -map 0:v:0 -map 0:a:0? -c:v libx264 -preset veryfast -crf 20 -maxrate 6000k -bufsize 18000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 160k -ar 44100 -vf 'scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2' -r 30"
        
        # Initializing tee muxer command with empty streams array
        local TEE_CMD="-f tee"
        local STREAMS=()

        # Configure stream for Twitch (Frankfurt Server)
        if [ -n "${TWITCH_STREAM_KEY}" ]; then
            echo "Configuring stream for Twitch"
            STREAMS+=("[f=flv:onfail=ignore]rtmp://fra02.contribute.live-video.net/app/${TWITCH_STREAM_KEY}")
        fi

        # Configure stream for YouTube
        if [ -n "${YOUTUBE_API_KEY}" ]; then
            echo "Configuring stream for YouTube"
            STREAMS+=("[f=flv:onfail=ignore]rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_API_KEY}")
        fi

        # Configure stream for Kick
        if [ -n "${KICK_STREAM_URL}" ] && [ -n "${KICK_STREAM_KEY}" ]; then
            echo "Configuring stream for Kick"
            STREAMS+=("[f=flv:onfail=ignore]${KICK_STREAM_URL}:443/app/${KICK_STREAM_KEY}")
        fi

        # Combine the stream configurations into a single string
        local TEE_TARGETS=$(IFS='|'; echo "${STREAMS[*]}")

        # Check if there are any configured streams and construct the final ffmpeg command
        if [ -n "${TEE_TARGETS}" ]; then
            FFMPEG_CMD+=" ${TEE_CMD} \"${TEE_TARGETS}\""
            echo "Final ffmpeg command: ${FFMPEG_CMD}"
            echo "Streaming $file to the specified platforms..."
            eval "${FFMPEG_CMD} &"
        else
            echo "No streaming destinations specified. Skipping $file."
        fi

        # Wait for the ffmpeg process to finish before moving to the next file
        wait
    done
}

if find "${VIDEO_DIR}" -type f \( -iname '*.mp4' -o -iname '*.mkv' \) -print -quit | grep -q .; then
    echo "Initiating stream_videos function..."
    LOOP_INDEFINITELY="${LOOP_INDEFINITELY:-false}"

    if [ "${LOOP_INDEFINITELY}" = "true" ]; then
        while true; do
            stream_videos
            echo "Looping indefinitely. Restarting streaming process..."
        done
    else
        stream_videos
    fi
else
    echo "No Videos Found. Exiting..."
    exit 1
fi

#!/bin/bash

# Stream videos to multiple platforms using ffmpeg and the tee muxer
stream_videos() {
    echo "Starting the streaming process..."

    # Access environment variables directly
    local VIDEO_DIR="${VIDEO_DIR}"
    local TWITCH_STREAM_KEY="${TWITCH_STREAM_KEY}"
    local YOUTUBE_API_KEY="${YOUTUBE_API_KEY}"
    local KICK_STREAM_URL="${KICK_STREAM_URL}"
    local KICK_STREAM_KEY="${KICK_STREAM_KEY}"

    echo "Video directory: ${VIDEO_DIR}"
    echo "Twitch Stream Key: ${TWITCH_STREAM_KEY}"
    echo "YouTube API Key: ${YOUTUBE_API_KEY}"
    echo "Kick Stream URL: ${KICK_STREAM_URL}"
    echo "Kick Stream Key: ${KICK_STREAM_KEY}"

    # Configure RTMP output streams array
    local STREAMS=()

    # Configure stream for Twitch
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

    # Check if any streams were configured
    if [ ${#STREAMS[@]} -eq 0 ]; then
        echo "Error: No stream destinations configured. Exiting."
        return 1
    fi

    # Combine stream configurations into a single pipe-separated string for tee
    local TEE_TARGETS
    TEE_TARGETS=$(IFS='|'; echo "${STREAMS[*]}")

    # Main infinite stream loop
    while true; do
        mapfile -t FILES < <(find "${VIDEO_DIR}" -type f \( -iname '*.mp4' -o -iname '*.mkv' \) | sort -V)

        for file in "${FILES[@]}"; do
            [ -f "$file" ] || continue
            echo "Preparing to stream file: $file"

            ffmpeg -re -nostdin \
              -analyzeduration 10M -probesize 10M \
              -i "$file" \
              -map 0:v:0 -map 0:a:0 \
              -c:v libx264 -preset ultrafast -tune zerolatency \
              -b:v 6000k -maxrate 6000k -bufsize 12000k -g 120 \
              -c:a aac -b:a 160k -ar 44100 -ac 2 \
              -flvflags no_duration_filesize \
              -f tee "$TEE_TARGETS"
        done

        echo "Finished video playlist loop. Restarting sequence in 2 seconds..."
        sleep 2
    done
}

# Run the function
stream_videos

#!/bin/bash

stream_videos() {
    echo "Starting the streaming process..."

    local VIDEO_DIR="${VIDEO_DIR}"
    local TWITCH_STREAM_KEY="${TWITCH_STREAM_KEY}"
    local YOUTUBE_API_KEY="${YOUTUBE_API_KEY}"
    local KICK_STREAM_URL="${KICK_STREAM_URL}"
    local KICK_STREAM_KEY="${KICK_STREAM_KEY}"

    local STREAMS=()

    if [ -n "${TWITCH_STREAM_KEY}" ]; then
        echo "Configuring stream for Twitch"
        STREAMS+=("[f=flv:onfail=ignore]rtmp://fra02.contribute.live-video.net/app/${TWITCH_STREAM_KEY}")
    fi

    if [ -n "${YOUTUBE_API_KEY}" ]; then
        echo "Configuring stream for YouTube"
        STREAMS+=("[f=flv:onfail=ignore]rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_API_KEY}")
    fi

    if [ -n "${KICK_STREAM_URL}" ] && [ -n "${KICK_STREAM_KEY}" ]; then
        echo "Configuring stream for Kick"
        STREAMS+=("[f=flv:onfail=ignore]${KICK_STREAM_URL}:443/app/${KICK_STREAM_KEY}")
    fi

    if [ ${#STREAMS[@]} -eq 0 ]; then
        echo "Error: No stream destinations configured. Exiting."
        return 1
    fi

    local TEE_TARGETS
    TEE_TARGETS=$(IFS='|'; echo "${STREAMS[*]}")

    while true; do
        mapfile -t FILES < <(find "${VIDEO_DIR}" -type f \( -iname '*.mp4' -o -iname '*.mkv' \) | sort -V)

        for file in "${FILES[@]}"; do
            [ -f "$file" ] || continue
            echo "Preparing to stream file: $file"

            ffmpeg -re -nostdin \
              -thread_queue_size 1024 \
              -i "$file" \
              -map 0:v:0 -map 0:a:0 \
              -c:v copy -tag:v 7 \
              -bsf:v h264_mp4toannexb \
              -c:a copy -tag:a 0 \
              -flvflags no_duration_filesize \
              -f tee "$TEE_TARGETS"
        done

        echo "Finished video playlist loop. Restarting sequence in 2 seconds..."
        sleep 2
    done
}

stream_videos

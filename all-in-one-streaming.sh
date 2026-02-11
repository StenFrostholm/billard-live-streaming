#!/bin/bash
# Billiard Live TV - All-in-One Processing Script
# Direct camera processing with local viewing
# Based on StenFrostholm's requirements and experiments
# =============================================
# CONFIGURATION SECTION
# =============================================
# Camera Configuration (Hikvision with your credentials)
BORD_CAMERA_URL="rtsp://admin:Pass123!@192.168.8.200:554/Streaming/Channels/101"
TAVLE_CAMERA_URL="rtsp://admin:Pass123!@192.168.8.201:554/Streaming/Channels/101"
# Lens Correction Coefficients (from your experiments)
BORD_LENS_K1="-0.13"
BORD_LENS_K2="-0.015"
TAVLE_LENS_K1="-0.09"
TAVLE_LENS_K2="-0.013"
LENS_INTERPOLATION="bilinear"
# Perspective Correction (from your experiments)
PERSPECTIVE_X0="0"
PERSPECTIVE_Y0="0"
PERSPECTIVE_X1="W"
PERSPECTIVE_Y1="0"
PERSPECTIVE_X2="-60"
PERSPECTIVE_Y2="469"
PERSPECTIVE_X3="615"
PERSPECTIVE_Y3="634"
# Output Configuration
OUTPUT_FILE="billiard_live.mp4"
# RTMP_STREAM_URL="rtmp://your_streaming_server/live/billiard_stream"  # Commented out for local testing
# RTSP_OUTPUT_URL="rtsp://localhost:8554/output"  # Commented out for future RTSP server
OUTPUT_RESOLUTION="1280x720"
OUTPUT_FPS="30"
# Overlay Configuration
TABLE_OVERLAY="table_overlay.png"
WHITEBOARD_OVERLAY="whiteboard_overlay.png"
TABLE_POSITION="100:100"
WHITEBOARD_POSITION="800:50"
# Local viewing configuration
LOCAL_VIEW_ENABLED=true
LOCAL_VIEW_FULLSCREEN=true
# =============================================
# INITIALIZATION FUNCTIONS
# =============================================
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg is not installed."
        exit 1
    fi
}
create_default_overlays() {
    if [ ! -f "$TABLE_OVERLAY" ]; then
        echo "Creating default table overlay..."
        ffmpeg -y -f lavfi -i color=c=0x00FF00:s=640x360 -frames:v 1 "$TABLE_OVERLAY"
    fi
    if [ ! -f "$WHITEBOARD_OVERLAY" ]; then
        echo "Creating default whiteboard overlay..."
        ffmpeg -y -f lavfi -i color=c=0xFFFFFF:s=400x300 -frames:v 1 "$WHITEBOARD_OVERLAY"
    fi
}
# =============================================
# MAIN PROCESSING FUNCTION
# =============================================
process_streams() {
    echo "Starting billiard live TV processing..."
    echo "Board camera: $BORD_CAMERA_URL"
    echo "Table camera: $TAVLE_CAMERA_URL"
    if [ "$LOCAL_VIEW_ENABLED" = true ]; then
        echo "Local viewing: ENABLED (fullscreen: $LOCAL_VIEW_FULLSCREEN)"
        echo "Output file: $OUTPUT_FILE"
    else
        echo "Local viewing: DISABLED"
        echo "Output file: $OUTPUT_FILE"
        # echo "RTMP stream: $RTMP_STREAM_URL"  # Would be enabled in production
    fi
    # Main FFmpeg processing pipeline
    ffmpeg \
        -rtsp_transport tcp \
        -i "$BORD_CAMERA_URL" \
        -rtsp_transport tcp \
        -i "$TAVLE_CAMERA_URL" \
        -i "$TABLE_OVERLAY" \
        -i "$WHITEBOARD_OVERLAY" \
        -filter_complex \
        "[0:v]lenscorrection=k1=$BORD_LENS_K1:k2=$BORD_LENS_K2:i=$LENS_INTERPOLATION,scale=640:360,setpts=PTS-STARTPTS[board]; \
         [1:v]lenscorrection=k1=$TAVLE_LENS_K1:k2=$TAVLE_LENS_K2:i=$LENS_INTERPOLATION,perspective=x0=$PERSPECTIVE_X0:y0=$PERSPECTIVE_Y0:x1=$PERSPECTIVE_X1:y1=$PERSPECTIVE_Y1:x2=$PERSPECTIVE_X2:y2=$PERSPECTIVE_Y2:x3=$PERSPECTIVE_X3:y3=$PERSPECTIVE_Y3,scale=640:360,setpts=PTS-STARTPTS[table]; \
         [2:v]scale=640:360,setpts=PTS-STARTPTS[table_overlay]; \
         [3:v]scale=400:300,setpts=PTS-STARTPTS[whiteboard_overlay]; \
         [board][table]hstack=inputs=2[background]; \
         [background][table_overlay]overlay=$TABLE_POSITION[with_table]; \
         [with_table][whiteboard_overlay]overlay=$WHITEBOARD_POSITION[final]" \
        -c:v libx264 \
        -preset ultrafast \
        -f mp4 \
        "$OUTPUT_FILE" \
        -f nut \
        - | ffplay -autoexit -fs "$OUTPUT_FILE"
}
# =============================================
# CLEANUP FUNCTION
# =============================================
cleanup() {
    echo ""
    echo "Stopping processing..."
    pkill -f "ffmpeg"
    pkill -f "ffplay"
    echo "Output saved to $OUTPUT_FILE"
    echo "To enable streaming for production:"
    echo "1. Uncomment RTMP_STREAM_URL in configuration"
    echo "2. Add -f flv \"$RTMP_STREAM_URL\" to ffmpeg command"
    echo "3. For RTSP output: uncomment RTSP_OUTPUT_URL and add -f rtsp \"$RTSP_OUTPUT_URL\""
}
# =============================================
# MAIN EXECUTION
# =============================================
check_ffmpeg
create_default_overlays
process_streams
trap cleanup EXIT

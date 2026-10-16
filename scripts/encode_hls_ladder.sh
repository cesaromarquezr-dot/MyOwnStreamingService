#!/usr/bin/env bash
set -Eeuo pipefail

# Create a compatible HLS VOD ladder without modifying the original source.
# Run inside an FFmpeg environment (for example a container mounted to your
# read-only source library and a separate writable output directory).
# Usage: ./scripts/encode_hls_ladder.sh /media/source.mkv /output/title-id

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input-video> <output-directory>" >&2
  exit 2
fi

INPUT="$1"
OUTPUT_DIR="$2"

if [[ ! -f "$INPUT" ]]; then
  echo "Input file does not exist: $INPUT" >&2
  exit 2
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required; run this script in an FFmpeg-enabled container." >&2
  exit 127
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required to validate input audio before generating the ladder." >&2
  exit 127
fi
if ! ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$INPUT" | grep -q '[0-9]'; then
  echo "This ladder script expects at least one audio stream in the source file." >&2
  exit 6
fi
if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q 'libx264'; then
  echo "This FFmpeg build must include libx264." >&2
  exit 3
fi
if [[ -e "$OUTPUT_DIR/master.m3u8" ]]; then
  echo "Output already contains master.m3u8; choose a new versioned output directory." >&2
  exit 4
fi

mkdir -p "$OUTPUT_DIR/1080p" "$OUTPUT_DIR/720p" "$OUTPUT_DIR/480p"

# One aligned encode produces the HLS master and three renditions. The source
# file is read only; generated manifests and segments are kept in OUTPUT_DIR.
ffmpeg -hide_banner -nostdin -y -i "$INPUT" \
  -filter_complex \
    "[0:v:0]split=3[v1080in][v720in][v480in];\
     [v1080in]scale=1920:1080:force_original_aspect_ratio=decrease:force_divisible_by=2,pad=1920:1080:(ow-iw)/2:(oh-ih)/2[v1080];\
     [v720in]scale=1280:720:force_original_aspect_ratio=decrease:force_divisible_by=2,pad=1280:720:(ow-iw)/2:(oh-ih)/2[v720];\
     [v480in]scale=854:480:force_original_aspect_ratio=decrease:force_divisible_by=2,pad=854:480:(ow-iw)/2:(oh-ih)/2[v480]" \
  -map "[v1080]" -map "0:a:0?" \
  -map "[v720]"  -map "0:a:0?" \
  -map "[v480]"  -map "0:a:0?" \
  -c:v libx264 -preset medium -profile:v high -pix_fmt yuv420p \
  -g 120 -keyint_min 48 -sc_threshold 0 \
  -force_key_frames "expr:gte(t,n_forced*4)" \
  -b:v:0 5000k -maxrate:v:0 5500k -bufsize:v:0 10000k \
  -b:v:1 2800k -maxrate:v:1 3080k -bufsize:v:1 5600k \
  -b:v:2 1300k -maxrate:v:2 1430k -bufsize:v:2 2600k \
  -c:a aac -ac:a:0 2 -ac:a:1 2 -ac:a:2 2 \
  -b:a:0 128k -b:a:1 96k -b:a:2 64k \
  -f hls -hls_time 4 -hls_playlist_type vod \
  -hls_flags independent_segments+temp_file \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0,name:1080p v:1,a:1,name:720p v:2,a:2,name:480p" \
  -hls_segment_filename "$OUTPUT_DIR/%v/segment_%05d.ts" \
  "$OUTPUT_DIR/%v/index.m3u8"

if [[ ! -s "$OUTPUT_DIR/master.m3u8" ]]; then
  echo "Encoding finished but master.m3u8 was not produced." >&2
  exit 5
fi

echo "HLS ladder created at: $OUTPUT_DIR/master.m3u8"
echo "Next: validate manifest/segments, register the rendition set with the trusted playback gateway, and serve it over HTTPS."

#!/usr/bin/env bash
#
# Usage: ./convert_to_hls_hevc.sh input.mp4 [--watermark]
# Splits input.mp4 into 6 HLS segments (1080p/720p/480p) using libx265,
# with optional watermark showing quality, codec, and segment index.

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <input.mp4> [--watermark]"
  exit 1
fi

INPUT="$1"
WATERMARK=false
[ "${2-}" == "--watermark" ] && WATERMARK=true

OUT_DIR="hls-output-hevc"

# ensure tools
for tool in ffmpeg ffprobe; do
  command -v $tool >/dev/null \
    || { echo "Install $tool (brew install $tool)"; exit 1; }
done

# 1. probe duration
duration=$(ffprobe -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$INPUT")

# 2. compute per-segment time
seg_time=$(awk -v d="$duration" 'BEGIN { printf "%.2f", d/6 }')
echo "⏱ Total duration: ${duration}s → segment length: ${seg_time}s"

# 3. prepare dirs
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/v0" "${OUT_DIR}/v1" "${OUT_DIR}/v2"

# 4. build optional drawtext
DRAW0=""; DRAW1=""; DRAW2=""
if $WATERMARK; then
  COMMON="drawtext=fontfile=/Library/Fonts/Arial.ttf:fontsize=48:fontcolor=white@0.8:box=1:boxcolor=black@0.5:boxborderw=5"
  DRAW0=",${COMMON}:text='1080p H265 %{eif\\:floor(t/${seg_time})\\:d}':x=10:y=10"
  DRAW1=",${COMMON}:text='720p  H265 %{eif\\:floor(t/${seg_time})\\:d}':x=10:y=10"
  DRAW2=",${COMMON}:text='480p  H265 %{eif\\:floor(t/${seg_time})\\:d}':x=10:y=10"
fi

# 5. run FFmpeg
(
  cd "${OUT_DIR}"
  ffmpeg -i "../${INPUT}" \
    -filter_complex "[0:v]split=3[v0][v1][v2];\
      [v0]scale=1920:1080${DRAW0}[out0];\
      [v1]scale=1280:720${DRAW1}[out1];\
      [v2]scale=854:480${DRAW2}[out2]" \
    -map "[out0]" -map 0:a -c:v:0 libx265 -tag:v:0 hvc1 -b:v:0 5000k \
    -map "[out1]" -map 0:a -c:v:1 libx265 -tag:v:1 hvc1 -b:v:1 2800k \
    -map "[out2]" -map 0:a -c:v:2 libx265 -tag:v:2 hvc1 -b:v:2 1400k \
    -var_stream_map "v:0,a:0 v:1,a:1 v:2,a:2" \
    -master_pl_name master.m3u8 \
    -hls_time "${seg_time}" \
    -hls_list_size 0 \
    -hls_segment_filename "v%v/seg%03d.ts" \
    -f hls "v%v/prog_index.m3u8"
)
echo "✅ HEVC HLS complete in '${OUT_DIR}/'"

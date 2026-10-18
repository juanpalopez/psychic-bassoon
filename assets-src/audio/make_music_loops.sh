#!/usr/bin/env bash
# Turns the owner's three full-length music wavs into seamless Vorbis loops for the game.
#
#   make_music_loops.sh <planning.wav> <wave.wav> <boss.wav> <output directory>
#
# Per track: cut the leading silence and the closing fade, then crossfade the last
# CROSSFADE seconds over the first ones, so the loop point has no gap and no dip.
# Output is stereo Vorbis (quality QUALITY); the web budget is in scripts/check-godot-size.mjs.
set -euo pipefail

CROSSFADE=2
TAIL_CUT=4
QUALITY=2

loop() {
  local input=$1 output=$2 tmp length
  tmp=$(mktemp -t loop).wav
  ffmpeg -v error -y -i "$input" -vn \
    -af "silenceremove=start_periods=1:start_threshold=-60dB,volume=-1dB" "$tmp.a.wav"
  length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp.a.wav")
  length=$(awk -v l="$length" -v t="$TAIL_CUT" 'BEGIN { printf "%.3f", l - t }')
  local before_tail
  before_tail=$(awk -v l="$length" -v c="$CROSSFADE" 'BEGIN { printf "%.3f", l - c }')
  ffmpeg -v error -y -i "$tmp.a.wav" -filter_complex "
    [0]atrim=0:$length,asetpts=PTS-STARTPTS,asplit=3[h][m][t];
    [h]atrim=0:$CROSSFADE,asetpts=PTS-STARTPTS[head];
    [m]atrim=$CROSSFADE:$before_tail,asetpts=PTS-STARTPTS[body];
    [t]atrim=$before_tail:$length,asetpts=PTS-STARTPTS[tail];
    [tail][head]acrossfade=d=$CROSSFADE:c1=qsin:c2=qsin[join];
    [join][body]concat=n=2:v=0:a=1[out]" \
    -map "[out]" -c:a libvorbis -q:a "$QUALITY" "$output"
  rm -f "$tmp" "$tmp.a.wav"
}

mkdir -p "$4"
loop "$1" "$4/music_tier1_planning.ogg"
loop "$2" "$4/music_tier2_wave.ogg"
loop "$3" "$4/music_tier3_boss.ogg"

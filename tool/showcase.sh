#!/usr/bin/env bash
# Re-shoots the README's animations.
#
#   tool/showcase.sh                 every scene
#   tool/showcase.sh switch,slider   just these (names from example/showcase/scenes.dart)
#
# Plays each scene in `example/showcase/scenes.dart` headless under
# flutter_tester — deterministic, no device, no screen recorder — one loop to
# settle and one to record, and fails if the recorded loop does not meet
# itself at the seam. Then packs each scene's frames into a looping webp in
# `doc/showcase/`.
#
# Each frame is encoded as only the rect that changed over the frame before,
# as the recorder found it exactly, and stacked by webpmux. Not img2webp: its
# sub-frame search treats a pixel that moved less than a quality-dependent
# tolerance (~4 code values at q80) as unchanged, so a slow fade is never
# written and the error accumulates — under the alert's barrier it reached
# twice that of one frame encoded alone, as blocks that outlive the dialog.
#
# Needs `cwebp` and `webpmux` (libwebp: `brew install webp`, `apt install webp`).
# SHOWCASE_QUALITY (default 80) is the lossy quality of the webp.
#
# SHOWCASE_DPR (default 2) is the density the scenes are shot at, and
# SHOWCASE_DIR (default doc/showcase) where the webp files go. The pubspec's
# screenshots are the same loops at half the size, because pub ships them:
#
#   SHOWCASE_DPR=1 SHOWCASE_DIR=doc/screenshots tool/showcase.sh
#
# SHOWCASE_MP4=<dir> also writes each loop as an H.264 mp4 without sound into
# <dir> — what Telegram plays inline and loops as a "GIF" (it converts a GIF
# into the same). Needs `ffmpeg` with libx264. Not for `doc/`: pub ships it.
# SHOWCASE_CRF (default 16) is its quality, lower is better.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/${SHOWCASE_DIR:-doc/showcase}"
quality="${SHOWCASE_QUALITY:-80}"

mp4="${SHOWCASE_MP4:-}"
crf="${SHOWCASE_CRF:-16}"
tools=(cwebp webpmux)
if [[ -n "$mp4" ]]; then
  tools+=(ffmpeg)
  mkdir -p "$mp4"
  mp4="$(cd "$mp4" && pwd)"
fi

for tool in "${tools[@]}"; do
  command -v "$tool" >/dev/null || { echo "$tool not found: install libwebp" >&2; exit 1; }
done

frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

defines=(--dart-define="SHOWCASE_OUT=$frames" --dart-define="SHOWCASE_DPR=${SHOWCASE_DPR:-2}")
if [[ $# -gt 0 ]]; then
  defines+=(--dart-define="SHOWCASE_SCENES=$1")
fi
(cd "$root/example" && flutter test showcase/showcase_test.dart "${defines[@]}")

# One scene: encode every changed rect, then fold the unchanged frames into
# the duration of the one they repeat.
pack() {
  local dir="$1" name delay frame x y w h
  name="$(basename "$dir")"
  delay="$(cat "$dir/delay_ms")"
  local files=() offsets=() durations=()
  while read -r frame x y w h; do
    if [[ "$x" == "-" ]]; then
      durations[${#durations[@]} - 1]=$((durations[${#durations[@]} - 1] + delay))
      continue
    fi
    # -sharp_yuv: the anaglyph's red and cyan edges are what 4:2:0 smears
    # first, and they are half of what the backdrop is for.
    cwebp -quiet -sharp_yuv -q "$quality" -m 6 -crop "$x" "$y" "$w" "$h" \
      "$dir/$frame.png" -o "$dir/$frame.webp"
    files+=("$dir/$frame.webp")
    offsets+=("+$x+$y")
    durations+=("$delay")
  done <"$dir/rects"
  local mux=()
  for i in "${!files[@]}"; do
    # No dispose, no blend: each frame replaces its rect on the canvas.
    mux+=(-frame "${files[i]}" "+${durations[i]}${offsets[i]}+0-b")
  done
  webpmux "${mux[@]}" -loop 0 -o "$out/$name.webp" >/dev/null

  if [[ -n "$mp4" ]]; then
    # yuv420p and bt709 tagged throughout: anything else either does not
    # play in a phone's hardware decoder or plays with shifted colours.
    ffmpeg -loglevel error -y -framerate "$((1000 / delay))" -i "$dir/%04d.png" \
      -c:v libx264 -preset veryslow -tune animation -crf "$crf" -pix_fmt yuv420p \
      -vf scale=out_color_matrix=bt709:out_range=tv \
      -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
      -an -movflags +faststart "$mp4/$name.mp4"
  fi
}

mkdir -p "$out"
pids=()
for dir in "$frames"/*/; do
  pack "${dir%/}" &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid"
done
ls -l "$out"/*.webp
if [[ -n "$mp4" ]]; then
  ls -l "$mp4"/*.mp4
fi

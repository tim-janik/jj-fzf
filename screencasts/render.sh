#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
die() { echo "${0##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  SCREENCASTSDIR="$PWD/${BASH_SOURCE[0]}" || SCREENCASTSDIR="${BASH_SOURCE[0]}"
export SCREENCASTSDIR="${SCREENCASTSDIR%/*}"

# Stop recording and render screencast output files
render_screencast()
{
  set -Eeuo pipefail # -x
  CASTFILE="$1"
  BASENAME="${CASTFILE%.cast}"
  # find "$BASENAME"* -printf "%8kk  %p\n"
  test -r "$BASENAME.cast" ||
    die "render_screencast: missing $BASENAME.cast"
  rm -f $BASENAME.mp4 $BASENAME.webp $BASENAME.gif $BASENAME.apng
  printf '  %-8s %s\n' RENDER $BASENAME
  # sed '$,/"\[exited]/d' "$BASENAME.cast"
  # asciinema-agg
  local ARGS=(
    # --idle-time-limit 1
    # --fps-cap 60
    # --renderer resvg
    --renderer fontdue	# good in agg-1.4.3
    --font-family "Fira Code Retina" --font-dir /usr/share/fonts/truetype/firacode/
    #--font-family "DejaVu Sans Mono" --font-dir /usr/share/fonts/truetype/dejavu/
    #--font-family "Noto Mono" --font-dir /usr/share/fonts/truetype/noto/
    #--font-family "Noto Sans Mono" --font-dir /usr/share/fonts/truetype/noto/
    --font-dir $PWD
    --font-size 17
    --theme asciinema
    --speed 1
  )
  test -z "$MAX_IDLE" ||
    ARGS+=( --idle-time-limit "$MAX_IDLE" )
  ( set -e -x
    agg "${ARGS[@]}" "$BASENAME.cast" "$BASENAME.gif"
    gif2webp "$BASENAME.gif" -min_size -metadata all -o "$BASENAME.webp" & p=$!
    # -preset placebo -preset veryslow -x264opts opencl
    ffmpeg -loglevel warning -stats -hwaccel auto -i "$BASENAME.gif" \
	   -c:v libx264 -crf 24 -tune animation -preset slower \
	   -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
           -y "$BASENAME.mp4" & f=$!
    wait -f $p && wait -f $f || exit $?
  )
  command -V notify-send >/dev/null 2>&1 &&
    notify-send -e -i system-run -t 5000 "Screencast ready: $BASENAME"
  find "$BASENAME"* -printf "%8kk  %p\n"
}

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/lib/setup.sh	# preflight.sh common.sh
jjfzf_tempd					# assigns $JJFZF_TEMPD
MAX_IDLE=
CASTS=()
while test $# -ne 0 ; do
  case "$1" in \
    -i)		shift; MAX_IDLE="$1" ;;
    *)		CASTS+=( "$1" ) ;;
  esac
  shift
done
test ${#CASTS[@]} -ge 1 ||
  CASTS=($SCREENCASTSDIR/*.cast)

# == Process ==
for f in "${CASTS[@]}" ; do
  render_screencast "$f"
  ls -l "${f%.cast}"*
done

#!/usr/bin/env bash
#
# Render the World Cup app and push it to a Tidbyt device.
#
# Usage:
#   export TIDBYT_TOKEN='<your API key from the Tidbyt mobile app>'
#   ./push.sh                  # push once to the default device
#   ./push.sh --loop           # re-render + push every 60s (live scores)
#   ./push.sh <device-id>      # push to a different device
#   ./push.sh <device-id> --loop
#
# The API key comes from the Tidbyt app: your device -> Settings -> Get API Key.
# It is read from the TIDBYT_TOKEN environment variable so it never lands in
# this repo or your shell history.

set -euo pipefail

DEFAULT_DEVICE="impartially-forceful-fun-batfish-f23"
APP="apps/worldcup/worldcup.star"
OUT="worldcup.webp"
INSTALLATION_ID="worldcup"
INTERVAL=60

DEVICE="$DEFAULT_DEVICE"
LOOP=false
for arg in "$@"; do
    case "$arg" in
        --loop) LOOP=true ;;
        *) DEVICE="$arg" ;;
    esac
done

if ! command -v pixlet >/dev/null 2>&1; then
    echo "error: pixlet not found. Install it first:" >&2
    echo "  brew install tidbyt/tidbyt/pixlet" >&2
    exit 1
fi

if [[ -z "${TIDBYT_TOKEN:-}" ]]; then
    echo "error: TIDBYT_TOKEN is not set. Get your API key from the Tidbyt app" >&2
    echo "(device -> Settings -> Get API Key), then:" >&2
    echo "  export TIDBYT_TOKEN='<key>'" >&2
    exit 1
fi

cd "$(dirname "$0")"

# First push shows the app on screen right away; loop refreshes use
# --background so they update the app without yanking the display to it.
push_once() {
    pixlet render "$APP"
    pixlet push --api-token "$TIDBYT_TOKEN" \
        --installation-id "$INSTALLATION_ID" \
        "$@" \
        "$DEVICE" "$OUT"
    echo "$(date '+%H:%M:%S') pushed to $DEVICE"
}

push_once
if $LOOP; then
    echo "looping every ${INTERVAL}s — Ctrl-C to stop"
    while sleep "$INTERVAL"; do
        # Keep the loop alive through transient network/API hiccups.
        push_once --background || echo "$(date '+%H:%M:%S') push failed; retrying in ${INTERVAL}s"
    done
fi

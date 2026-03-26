#!/bin/sh

FLAGS_PATH="${XDG_CONFIG_HOME}/fluxer-flags.conf"

if [ -f "${FLAGS_PATH}" ]; then
    mapfile -t FLAGS <<< "$(grep -Ev '^\s*$|^#' "${FLAGS_PATH}")"
fi

exec zypak-wrapper /app/fluxer/fluxer_desktop "${FLAGS[@]}" "$@"
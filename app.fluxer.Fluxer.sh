#!/bin/sh

FLAGS_PATH="${XDG_CONFIG_HOME}/fluxer-flags.conf"

if [ -f "${FLAGS_PATH}" ]; then
    mapfile -t FLAGS <<< "$(grep -Ev '^\s*$|^#' "${FLAGS_PATH}")"
fi

ARCH="$([[ "$(uname -m)" =~ ^(aarch64|arm64)$ ]] && echo "arm64" || echo "x64")"
UIOHOOK_NAPI="$(ls "/app/fluxer/resources/app.asar.unpacked/node_modules/uiohook-napi/prebuilds/linux-$ARCH/"*.node)"

export ZYPAK_LD_PRELOAD="$ZYPAK_LD_PRELOAD:$UIOHOOK_NAPI"

exec zypak-wrapper /app/fluxer/fluxer_desktop --disable-features=WaylandWpColorManagerV1 "${FLAGS[@]}" "$@"

#!/usr/bin/env bash

set -euo pipefail

CUR_DIR="$PWD"

COMMIT=$(awk '
  /url: https:\/\/github\.com\/fluxerapp\/fluxer\.git$/ { found=1; next }
  found && /^[[:space:]]*commit:/ { print $2; exit }
  found && /^[[:space:]]*- / { exit }
' "$CUR_DIR/app.fluxer.Fluxer.yml")

echo ""
SOURCE_URL="https://github.com/fluxerapp/fluxer"

WORKDIR="$(mktemp -d -t fluxer-flatpak-XXXXXX)"

cd "$WORKDIR"

python -m venv venv

source ./venv/bin/activate

git clone $SOURCE_URL fluxer

git -C fluxer checkout "$COMMIT"

cd "./fluxer"

pip install pipx

pipx install git+https://github.com/flatpak/flatpak-builder-tools.git#subdirectory=node  --force

flatpak-node-generator pnpm "./pnpm-lock.yaml" -o "pnpm-sources.json" --pnpm-store-version v11

pip install flatpak-cargo-generator

find "." -name Cargo.lock | while read -r lockfile; do
    flatpak-cargo-generator "$lockfile" -o "$(dirname "$lockfile")/cargo-sources.json"
done


jq -s '
    map(.[])
    | unique | sort_by(.type == "shell")
' $(find . -name cargo-sources.json -type f) > "merged-cargo-sources.json"

jq '
    (
    map(select(.type == "inline" and .dest == "cargo" and ."dest-filename" == "config") | .contents) as $items
    | $items | map(
        select(. as $x | ($items | map(select(. != $x and contains($x))) | length) == 0)
    ) | join("\n")
    ) as $merged_contents | map(
        select(.type != "inline" or .dest != "cargo" or ."dest-filename" != "config")
    ) | . + [{
        "type": "inline",
        "contents": $merged_contents,
        "dest": "cargo",
        "dest-filename": "config"
    }]
' merged-cargo-sources.json > merged-fixed-cargo-sources.json

jq '
  map(if .type == "shell"
      and (.commands | length == 1)
      and (.commands[0] | test("cp -r --reflink=auto \"flatpak-cargo/git/deepfilternet-[^/]+/libDF\""))
    then
      .commands = [
        "cp -r --reflink=auto flatpak-cargo/git/deepfilternet-*/libDF/* cargo/vendor/deep_filter",
        "cp -r flatpak-cargo/git/deepfilternet-*/models cargo/vendor"
      ]
    else
      .
    end)
' merged-fixed-cargo-sources.json > merged-fixed-deep_filter-cargo-sources.json

WASM_BINDGEN_VERSION=$(sed -n 's/^const LIBFLUXCORE_WASM_BINDGEN_VERSION: &str = "\(.*\)";$/\1/p' tools/ci/src/app_wasm.rs)

WASM_BINDGEN_VERSION=$(sed -n 's/^const LIBFLUXCORE_WASM_BINDGEN_VERSION: &str = "\(.*\)";$/\1/p' tools/ci/src/app_wasm.rs)

for arch in x86_64 aarch64; do
    url="https://github.com/wasm-bindgen/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-${arch}-unknown-linux-musl.tar.gz"
    sha256=$(curl -fsSL "$url" | sha256sum | cut -d ' ' -f 1)

    jq --arg arch "$arch" \
       --arg url "$url" \
       --arg sha256 "$sha256" \
       'map(
          if .dest == "wasm-bindgen" and
             ((.["only-arches"] // []) | index($arch)) then
            .url = $url | .sha256 = $sha256
          else
            .
          end
       )' "$CUR_DIR/wasm-bindgen.json" > "wasm-bindgen.json" &&
       cp "wasm-bindgen.json" "$CUR_DIR/wasm-bindgen.json" || exit 1
done

cp "pnpm-sources.json" "$CUR_DIR/pnpm-sources.json"

cp "merged-fixed-deep_filter-cargo-sources.json" "$CUR_DIR/cargo-sources.json"


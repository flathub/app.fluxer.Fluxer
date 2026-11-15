#!/usr/bin/env bash
set -euo pipefail

CUR_DIR="$PWD"
UPSTREAM_VER=$(curl -fsS https://pkgs.fluxer.com/desktop/stable/linux/x64/modules.json | jq -r .shell.latest_version)
TAG="refs/tags/fluxer-desktop-stable@${UPSTREAM_VER}"
NEW_COMMIT=$(git ls-remote https://github.com/fluxerapp/fluxer "$TAG" "$TAG^{}" | tail -n1 | cut -f1)
SOURCE_URL="https://github.com/fluxerapp/fluxer"
WORKDIR="$(mktemp -d -t fluxer-flatpak-XXXXXX)"
cd "$WORKDIR"
python -m venv venv
source ./venv/bin/activate
git clone $SOURCE_URL fluxer
git -C fluxer checkout "$NEW_COMMIT"
cd "./fluxer"

pip install pipx
pip install flatpak-cargo-generator
pipx install git+https://github.com/flatpak/flatpak-builder-tools.git#subdirectory=node  --force

flatpak-node-generator pnpm "./pnpm-lock.yaml" -o "pnpm-sources.json" --pnpm-store-version v11
flatpak-cargo-generator Cargo.lock -o cargo-sources.json
cp cargo-sources.json "$CUR_DIR/source_files/cargo-sources.json"

WASM_BINDGEN_VERSION=$(awk '$0=="name = \"wasm-bindgen\""{getline; gsub(/"/,"",$3); print $3; exit}' Cargo.lock)

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
       )' "$CUR_DIR/source_files/wasm-bindgen.json" > "wasm-bindgen.json" &&
       cp "wasm-bindgen.json" "$CUR_DIR/source_files/wasm-bindgen.json" || exit 1
done

cp "pnpm-sources.json" "$CUR_DIR/source_files/pnpm-sources.json"

# Custom fluxer source update script to be compliant with PACKAGING.md (https://github.com/fluxerapp/fluxer/blob/main/fluxer_desktop/PACKAGING.md)
echo "Checking for a new fluxer source version"

LOCAL_VER=$(yq '
  .modules[]
  | select(tag == "!!map" and .name == "fluxer")
  | .sources[]
  | select(tag == "!!map" and .type == "git")
  | .tag | split("@") | .[1]
' $CUR_DIR/app.fluxer.Fluxer.yml)

if [ "$LOCAL_VER" = "$UPSTREAM_VER" ]; then
	echo "Source is up to date"
	exit
else
	echo $'\nNew version available:'
	echo "$LOCAL_VER -> $UPSTREAM_VER"

    export NEW_COMMIT
    export UPSTREAM_VER
    yq -i '
      (.modules[]
      | select(tag == "!!map" and .name == "fluxer")
      | .sources[]
      | select(tag == "!!map" and .type == "git")
      ) |= (
      .tag = "fluxer-desktop-stable@" + strenv(UPSTREAM_VER)
      | .commit = strenv(NEW_COMMIT)
      )
    ' $CUR_DIR/app.fluxer.Fluxer.yml
    echo $'Fluxer source has been updated\n'
fi

#!/usr/bin/env bash
# Downloads one mirrord release asset for this runner, checks it against the checksum published
# with the release (and against EXPECTED_CHECKSUM when the workflow pins one), and puts the
# binary in INSTALL_DIR. Runs only on a cache miss; the composite action sets the env.
set -euo pipefail

: "${MIRRORD_VERSION:?MIRRORD_VERSION is required}"
: "${INSTALL_DIR:?INSTALL_DIR is required}"
: "${RUNNER_OS:?RUNNER_OS is required}"
: "${RUNNER_ARCH:?RUNNER_ARCH is required}"
EXPECTED_CHECKSUM="${EXPECTED_CHECKSUM:-}"

# Each platform ships a different asset and checksum file: Linux and macOS a zip with a
# `.shasum256` in `sha256sum` format, Windows a bare exe with a `.sha256` holding only the hash.
case "$RUNNER_OS" in
  Linux)
    case "$RUNNER_ARCH" in
      X64) arch=x86_64 ;;
      ARM64) arch=aarch64 ;;
      *) echo "::error::mirrord has no Linux build for $RUNNER_ARCH"; exit 1 ;;
    esac
    asset="mirrord_linux_${arch}.zip"
    checksum_file="mirrord_linux_${arch}.shasum256"
    ;;
  macOS)
    asset="mirrord_mac_universal.zip"
    checksum_file="mirrord_mac_universal.shasum256"
    ;;
  Windows)
    asset="mirrord.exe"
    checksum_file="mirrord.exe.sha256"
    ;;
  *)
    echo "::error::mirrord has no build for $RUNNER_OS"
    exit 1
    ;;
esac

base_url="https://github.com/metalbear-co/mirrord/releases/download/${MIRRORD_VERSION}"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

echo "Downloading mirrord ${MIRRORD_VERSION} (${asset})"
for file in "$asset" "$checksum_file"; do
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "${work_dir}/${file}" "${base_url}/${file}"; then
    echo "::error::Failed to download ${base_url}/${file}; check that release ${MIRRORD_VERSION} exists and ships ${file}"
    exit 1
  fi
done

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

actual=$(sha256_of "${work_dir}/${asset}" | tr '[:upper:]' '[:lower:]')
published=$(awk 'NF { print $1; exit }' "${work_dir}/${checksum_file}" | tr '[:upper:]' '[:lower:]')

if [[ "$actual" != "$published" ]]; then
  echo "::error::${asset} does not match the checksum published with release ${MIRRORD_VERSION}: got ${actual}, release says ${published}. The download is corrupt or tampered with; do not use it."
  exit 1
fi
if [[ -n "$EXPECTED_CHECKSUM" && "$actual" != "$EXPECTED_CHECKSUM" ]]; then
  echo "::error::${asset} of release ${MIRRORD_VERSION} has SHA-256 ${actual}, the workflow pins ${EXPECTED_CHECKSUM}. Update the pin if the release was republished, otherwise do not use it."
  exit 1
fi
echo "Verified ${asset}: sha256 ${actual}"

mkdir -p "$INSTALL_DIR"
case "$asset" in
  *.zip)
    unzip -o -q "${work_dir}/${asset}" -d "$work_dir"
    install -m 0755 "${work_dir}/mirrord" "${INSTALL_DIR}/mirrord"
    ;;
  *)
    cp "${work_dir}/${asset}" "${INSTALL_DIR}/mirrord.exe"
    ;;
esac
echo "Installed mirrord ${MIRRORD_VERSION} into ${INSTALL_DIR}"

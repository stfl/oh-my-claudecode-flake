#!/usr/bin/env bash
set -euo pipefail

PACKAGE="oh-my-claude-sisyphus"
REGISTRY="https://registry.npmjs.org"

echo "Fetching latest version of ${PACKAGE}..."
LATEST=$(curl -fsSL "${REGISTRY}/${PACKAGE}/latest" | jq -r '.version')
CURRENT=$(grep 'version = "' flake.nix | head -1 | sed 's/.*version = "\(.*\)";.*/\1/')

echo "Current: ${CURRENT}"
echo "Latest:  ${LATEST}"

if [ "${CURRENT}" = "${LATEST}" ]; then
  echo "Already up to date."
  exit 0
fi

TARBALL_URL="${REGISTRY}/${PACKAGE}/-/${PACKAGE}-${LATEST}.tgz"
echo "Computing hash for ${TARBALL_URL}..."
HASH=$(nix-prefetch-url --type sha256 "${TARBALL_URL}" 2>/dev/null)
SRI=$(nix hash to-sri --type sha256 "${HASH}")
echo "Hash: ${SRI}"

sed -i "s|version = \"${CURRENT}\";|version = \"${LATEST}\";|g" flake.nix
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${SRI}\";|" flake.nix

echo "Updating flake.lock..."
nix flake update nixpkgs

echo ""
echo "Updated ${PACKAGE} ${CURRENT} -> ${LATEST}"
echo "Verify with: nix build .#omc && ./result/bin/omc --version"

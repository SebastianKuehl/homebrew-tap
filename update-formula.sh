#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <formula-name>"
  exit 1
fi

FORMULA_NAME="$1"
FORMULA_DIR="Formula"
FORMULA_FILE="${FORMULA_DIR}/${FORMULA_NAME}.rb"

if [ ! -f "$FORMULA_FILE" ]; then
  echo "Formula file not found: $FORMULA_FILE"
  exit 1
fi

cd "$FORMULA_DIR"

HOMEPAGE=$(
  awk -F'"' '/^[[:space:]]*homepage[[:space:]]+"/ { print $2; exit }' \
    "${FORMULA_NAME}.rb"
)

if [ -z "${HOMEPAGE:-}" ]; then
  echo "Could not find homepage in ${FORMULA_NAME}.rb"
  exit 1
fi

if [[ "$HOMEPAGE" =~ ^https://github.com/([^/]+)/([^/]+)/?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "Homepage is not a supported GitHub repo URL: $HOMEPAGE"
  exit 1
fi

LATEST_TAG=$(
  git ls-remote --tags --refs "https://github.com/${OWNER}/${REPO}.git" |
    awk '{print $2}' |
    sed 's#refs/tags/##' |
    sort -V |
    tail -n1
)

if [ -z "${LATEST_TAG:-}" ]; then
  echo "Could not determine latest tag for ${OWNER}/${REPO}"
  exit 1
fi

NEW_URL="https://github.com/${OWNER}/${REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "$NEW_URL" -o "$TMP_FILE"
NEW_SHA256="$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')"

awk -v new_url="$NEW_URL" -v new_sha="$NEW_SHA256" '
  BEGIN {
    updated_url = 0
    updated_sha = 0
  }
  /^[[:space:]]*url[[:space:]]+"/ && updated_url == 0 {
    sub(/"[^"]*"/, "\"" new_url "\"")
    updated_url = 1
  }
  /^[[:space:]]*sha256[[:space:]]+"/ && updated_sha == 0 {
    sub(/"[^"]*"/, "\"" new_sha "\"")
    updated_sha = 1
  }
  { print }
' "${FORMULA_NAME}.rb" > "${FORMULA_NAME}.rb.tmp"

mv "${FORMULA_NAME}.rb.tmp" "${FORMULA_NAME}.rb"

echo "Updated ${FORMULA_NAME}.rb"
echo "Tag:    ${LATEST_TAG}"
echo "URL:    ${NEW_URL}"
echo "SHA256: ${NEW_SHA256}"
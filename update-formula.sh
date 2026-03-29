#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <formula-name>"
  exit 1
fi

FORMULA_NAME="$1"
FORMULA_DIR="Formula"
FORMULA_FILE="${FORMULA_DIR}/${FORMULA_NAME}.rb"

if [[ ! -f "${FORMULA_FILE}" ]]
then
  echo "Formula file not found: ${FORMULA_FILE}"
  exit 1
fi

cd "${FORMULA_DIR}"

HOMEPAGE=$(
  awk -F'"' '/^[[:space:]]*homepage[[:space:]]+"/ { print $2; exit }' \
    "${FORMULA_NAME}.rb"
)

if [[ -z "${HOMEPAGE:-}" ]]
then
  echo "Could not find homepage in ${FORMULA_NAME}.rb"
  exit 1
fi

if [[ "${HOMEPAGE}" =~ ^https://github.com/([^/]+)/([^/]+)/?$ ]]
then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "Homepage is not a supported GitHub repo URL: ${HOMEPAGE}"
  exit 1
fi

ALL_TAGS=$(
  git ls-remote --tags --refs "https://github.com/${OWNER}/${REPO}.git" |
    awk '{print $2}' |
    sed 's#refs/tags/##' |
    sort -V
)

if [[ -z "${ALL_TAGS:-}" ]]
then
  echo "Could not find any tags for ${OWNER}/${REPO}"
  exit 1
fi

if command -v fzf >/dev/null 2>&1
then
  # Temporarily disable set -e so a cancelled fzf (exit 130) doesn't kill the script
  set +e
  CHOSEN_TAG=$(echo "${ALL_TAGS}" | fzf --tac --prompt="Select tag> " --height=15 --layout=reverse --border)
  FZF_EXIT=$?
  set -e
  if [[ "${FZF_EXIT}" -ne 0 ]] || [[ -z "${CHOSEN_TAG:-}" ]]
  then
    echo "No tag selected. Aborting."
    exit 1
  fi
else
  # Fallback: show numbered list with optional filter
  while true
  do
    printf "Filter tags (leave blank to show all): "
    read -r FILTER
    if [[ -z "${FILTER}" ]]
    then
      FILTERED="${ALL_TAGS}"
    else
      # -F: literal string match; -- guards against filter strings starting with '-'
      FILTERED=$(echo "${ALL_TAGS}" | grep -iF -- "${FILTER}" || true)
    fi

    if [[ -z "${FILTERED}" ]]
    then
      echo "No tags match '${FILTER}'. Try again."
      continue
    fi

    echo ""
    i=1
    while IFS= read -r tag
    do
      printf "  %3d) %s\n" "${i}" "${tag}"
      i=$((i + 1))
    done <<<"${FILTERED}"
    echo ""

    TAG_COUNT=$(echo "${FILTERED}" | wc -l | tr -d ' ')
    printf "Choose a tag [1-%s]: " "${TAG_COUNT}"
    read -r CHOICE

    if ! [[ "${CHOICE}" =~ ^[0-9]+$ ]] || [[ "${CHOICE}" -lt 1 ]] || [[ "${CHOICE}" -gt "${TAG_COUNT}" ]]
    then
      echo "Invalid choice. Try again."
      continue
    fi

    CHOSEN_TAG=$(echo "${FILTERED}" | sed -n "${CHOICE}p")
    break
  done
fi

if [[ -z "${CHOSEN_TAG:-}" ]]
then
  echo "No tag selected. Aborting."
  exit 1
fi

LATEST_TAG="${CHOSEN_TAG}"

NEW_URL="https://github.com/${OWNER}/${REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "${NEW_URL}" -o "${TMP_FILE}"
NEW_SHA256="$(shasum -a 256 "${TMP_FILE}" | awk '{print $1}')"

awk -v new_url="${NEW_URL}" -v new_sha="${NEW_SHA256}" '
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
' "${FORMULA_NAME}.rb" >"${FORMULA_NAME}.rb.tmp"

mv "${FORMULA_NAME}.rb.tmp" "${FORMULA_NAME}.rb"

echo "Updated ${FORMULA_NAME}.rb"
echo "Tag:    ${LATEST_TAG}"
echo "URL:    ${NEW_URL}"
echo "SHA256: ${NEW_SHA256}"

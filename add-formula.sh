#!/usr/bin/env bash
set -euo pipefail

FORMULA_DIR="Formula"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1
  then
    echo "Required command not found: ${command_name}"
    exit 1
  fi
}

cleanup() {
  rm -f "${TMP_ARCHIVE:-}"
  rm -rf "${TMP_DIR:-}"
}

select_from_list() {
  local prompt="$1"
  local options="$2"
  local filter_prompt="$3"
  local selected
  local count
  local choice
  local filtered
  local i

  if [[ -z "${options:-}" ]]
  then
    echo "No options available for ${prompt}" >&2
    return 1
  fi

  if command -v fzf >/dev/null 2>&1
  then
    set +e
    selected=$(printf '%s\n' "${options}" | fzf --prompt="${prompt}> " --height=15 --layout=reverse --border)
    local fzf_exit=$?
    set -e
    if [[ "${fzf_exit}" -ne 0 ]] || [[ -z "${selected:-}" ]]
    then
      echo "No selection made. Aborting." >&2
      exit 1
    fi

    printf '%s\n' "${selected}"
    return 0
  fi

  while true
  do
    printf "%s" "${filter_prompt}" >&2
    read -r choice

    if [[ -z "${choice}" ]]
    then
      filtered="${options}"
    else
      filtered=$(printf '%s\n' "${options}" | grep -iF -- "${choice}" || true)
    fi

    if [[ -z "${filtered}" ]]
    then
      echo "No matches found. Try again." >&2
      continue
    fi

    echo "" >&2
    i=1
    while IFS= read -r item
    do
      printf "  %3d) %s\n" "${i}" "${item}" >&2
      i=$((i + 1))
    done <<<"${filtered}"
    echo "" >&2

    count=$(printf '%s\n' "${filtered}" | wc -l | tr -d ' ')
    printf "Choose %s [1-%s]: " "${prompt}" "${count}" >&2
    read -r choice

    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || [[ "${choice}" -lt 1 ]] || [[ "${choice}" -gt "${count}" ]]
    then
      echo "Invalid choice. Try again." >&2
      continue
    fi

    printf '%s\n' "${filtered}" | sed -n "${choice}p"
    return 0
  done
}

github_login() {
  gh api user --jq '.login'
}

repo_options() {
  local login="$1"

  gh repo list "${login}" \
    --source \
    --visibility public \
    --limit 200 \
    --json nameWithOwner,description \
    --jq '.[] | "\(.nameWithOwner)\t\(.description // "")"'
}

repo_tags() {
  local owner="$1"
  local repo="$2"

  git ls-remote --tags --refs "https://github.com/${owner}/${repo}.git" |
    awk '{print $2}' |
    sed 's#refs/tags/##' |
    sort -V
}

url_encode() {
  ruby -ruri -e 'puts URI::DEFAULT_PARSER.escape(ARGV[0])' "$1"
}

formula_class_name() {
  local formula_name="$1"
  ruby -e '
    digit_words = {
      "0" => "Zero", "1" => "One", "2" => "Two", "3" => "Three", "4" => "Four",
      "5" => "Five", "6" => "Six", "7" => "Seven", "8" => "Eight", "9" => "Nine"
    }

    class_name = ARGV[0].split(/[^a-zA-Z0-9]+/).reject(&:empty?).map do |part|
      part.scan(/[0-9]+|[A-Za-z]+/).map do |chunk|
        if chunk.match?(/\A[0-9]+\z/)
          chunk.chars.map { |char| digit_words.fetch(char) }.join
        else
          chunk[0].upcase + chunk[1..].downcase
        end
      end.join
    end.join

    puts class_name
  ' "${formula_name}"
}

ruby_single_quoted_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\'/\\\'}"
  printf "'%s'" "${value}"
}

repo_metadata() {
  local owner="$1"
  local repo="$2"
  gh repo view "${owner}/${repo}" --json description,licenseInfo --jq '[.description // "", (.licenseInfo.spdxId // "")] | @tsv'
}

parse_rust_package_name() {
  local cargo_toml="$1"
  parse_rust_package_field "${cargo_toml}" "name"
}

parse_rust_default_run() {
  local cargo_toml="$1"
  parse_rust_package_field "${cargo_toml}" "default-run"
}

parse_rust_autobins() {
  local cargo_toml="$1"
  parse_rust_package_field "${cargo_toml}" "autobins"
}

parse_rust_package_field() {
  local cargo_toml="$1"
  local field_name="$2"

  awk '
    BEGIN {
      field_name = ARGV[2]
      ARGV[2] = ""
    }
    /^\[package\]/ { in_package = 1; next }
    /^\[/ && $0 !~ /^\[package\]/ { in_package = 0 }
    in_package && $0 ~ "^[[:space:]]*" field_name "[[:space:]]*=" {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]+#.*$/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) {
        sub(/^"/, "", value)
        sub(/"$/, "", value)
      }
      print value
      exit
    }
  ' "${cargo_toml}" "${field_name}"
}

parse_rust_declared_bin_names() {
  local cargo_toml="$1"

  awk '
    /^\[\[bin\]\]/ { in_bin = 1; next }
    /^\[/ && $0 !~ /^\[\[bin\]\]/ { in_bin = 0 }
    in_bin && /^[[:space:]]*name[[:space:]]*=/ {
      value = $0
      sub(/^[^=]*=[[:space:]]*"/, "", value)
      sub(/".*$/, "", value)
      print value
    }
  ' "${cargo_toml}"
}

infer_rust_bin_names() {
  local source_dir="$1"
  local package_name="$2"
  local directory
  local nested_bin_dirs_file="${TMP_DIR}/rust-bin-dirs.txt"

  if [[ -f "${source_dir}/src/main.rs" ]]
  then
    printf '%s\n' "${package_name}"
  fi

  if [[ -d "${source_dir}/src/bin" ]]
  then
    find "${source_dir}/src/bin" -mindepth 1 -maxdepth 1 -type f -name '*.rs' -exec basename {} .rs \;
    find "${source_dir}/src/bin" -mindepth 2 -maxdepth 2 -type f -name 'main.rs' -exec dirname {} \; >"${nested_bin_dirs_file}"
    while IFS= read -r directory
    do
      basename "${directory}"
    done <"${nested_bin_dirs_file}"
  fi
}

detect_rust_binary_name() {
  local source_dir="$1"
  local cargo_toml="${source_dir}/Cargo.toml"
  local package_name
  local default_run
  local autobins
  local declared_bins
  local inferred_bins
  local candidates
  local candidate_count

  package_name="$(parse_rust_package_name "${cargo_toml}")"
  default_run="$(parse_rust_default_run "${cargo_toml}")"
  autobins="$(parse_rust_autobins "${cargo_toml}")"

  if [[ -z "${package_name:-}" ]]
  then
    echo "Could not determine Rust package name from Cargo.toml"
    exit 1
  fi

  declared_bins="$(parse_rust_declared_bin_names "${cargo_toml}")"
  if [[ "${autobins:-true}" == "false" ]]
  then
    inferred_bins=""
  else
    inferred_bins="$(infer_rust_bin_names "${source_dir}" "${package_name}")"
  fi

  candidates="$(printf '%s\n%s\n' "${declared_bins}" "${inferred_bins}" | sed '/^$/d' | sort -u)"
  candidate_count=$(printf '%s\n' "${candidates}" | sed '/^$/d' | wc -l | tr -d ' ')

  if [[ -n "${default_run:-}" ]]
  then
    printf '%s\n' "${default_run}"
    return 0
  fi

  if [[ "${candidate_count}" -eq 1 ]]
  then
    printf '%s\n' "${candidates}" | sed -n '1p'
    return 0
  fi

  if [[ "${candidate_count}" -eq 0 ]]
  then
    echo "Rust repo does not expose an installable binary target."
    exit 1
  fi

  echo "Rust repo exposes multiple binary targets. Add package.default-run or reduce the binary targets before generating a formula."
  exit 1
}

count_root_go_mains() {
  local source_dir="$1"
  local count=0
  local file
  local root_go_files="${TMP_DIR}/root-go-files.txt"

  find "${source_dir}" -maxdepth 1 -type f -name '*.go' -print0 >"${root_go_files}"
  while IFS= read -r -d '' file
  do
    if grep -q '^package main$' "${file}"
    then
      count=$((count + 1))
    fi
  done <"${root_go_files}"

  printf '%s\n' "${count}"
}

go_cmd_targets() {
  local source_dir="$1"
  local directory
  local file
  local has_main
  local cmd_dirs_file="${TMP_DIR}/cmd-dirs.txt"
  local cmd_go_files="${TMP_DIR}/cmd-go-files.txt"

  if [[ ! -d "${source_dir}/cmd" ]]
  then
    return 0
  fi

  find "${source_dir}/cmd" -mindepth 1 -maxdepth 1 -type d >"${cmd_dirs_file}"

  while IFS= read -r directory
  do
    has_main=0
    find "${directory}" -type f -name '*.go' -print0 >"${cmd_go_files}"
    while IFS= read -r -d '' file
    do
      if grep -q '^package main$' "${file}"
      then
        has_main=1
        break
      fi
    done <"${cmd_go_files}"

    if [[ "${has_main}" -eq 1 ]]
    then
      basename "${directory}"
    fi
  done <"${cmd_dirs_file}"
}

detect_build_strategy() {
  local source_dir="$1"

  if [[ -f "${source_dir}/Cargo.toml" ]]
  then
    BUILD_SYSTEM="rust"
    BINARY_NAME="$(detect_rust_binary_name "${source_dir}")"
    return 0
  fi

  if [[ -f "${source_dir}/go.mod" ]]
  then
    local root_main_count
    local cmd_targets
    local cmd_target_count

    root_main_count="$(count_root_go_mains "${source_dir}")"
    cmd_targets="$(go_cmd_targets "${source_dir}")"
    cmd_target_count=$(printf '%s\n' "${cmd_targets}" | sed '/^$/d' | wc -l | tr -d ' ')

    if [[ "${root_main_count}" -gt 0 ]] && [[ "${cmd_target_count}" -eq 0 ]]
    then
      BUILD_SYSTEM="go-root"
      BINARY_NAME="${REPO}"
      GO_BUILD_TARGET="."
      return 0
    fi

    if [[ "${root_main_count}" -eq 0 ]] && [[ "${cmd_target_count}" -eq 1 ]]
    then
      BUILD_SYSTEM="go-cmd"
      BINARY_NAME="$(printf '%s\n' "${cmd_targets}" | sed -n '1p')"
      GO_BUILD_TARGET="./cmd/${BINARY_NAME}"
      return 0
    fi

    echo "Go repo layout is ambiguous. Supported layouts: a single root main package or exactly one cmd/* binary."
    exit 1
  fi

  echo "Unsupported repo layout. Expected Cargo.toml for Rust or go.mod for Go."
  exit 1
}

formula_contents() {
  local class_name="$1"
  local description_literal="$2"
  local homepage_literal="$3"
  local archive_url_literal="$4"
  local sha256_literal="$5"
  local license_line="$6"
  local binary_literal="$7"
  local install_block_content

  install_block_content="$(install_block)"

  cat <<EOF
class ${class_name} < Formula
  desc ${description_literal}
  homepage ${homepage_literal}
  url ${archive_url_literal}
  sha256 ${sha256_literal}
${license_line}

${install_block_content}

  test do
    assert_predicate bin/${binary_literal}, :executable?
  end
end
EOF
}

install_block() {
  local binary_literal
  local build_target_literal

  case "${BUILD_SYSTEM}" in
    rust)
      cat <<EOF
  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: ".")
  end
EOF
      ;;
    go-root|go-cmd)
      binary_literal="$(ruby_single_quoted_string "${BINARY_NAME}")"
      build_target_literal="$(ruby_single_quoted_string "${GO_BUILD_TARGET}")"
      cat <<EOF
  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(output: bin/${binary_literal}), ${build_target_literal}
  end
EOF
      ;;
    *)
      echo "Unsupported build system: ${BUILD_SYSTEM}" >&2
      exit 1
      ;;
  esac
}

main() {
  local repo_options_output
  local repo_metadata_output

  require_command gh
  require_command git
  require_command curl
  require_command ruby
  require_command tar

  if [[ ! -d "${FORMULA_DIR}" ]]
  then
    echo "Formula directory not found: ${FORMULA_DIR}"
    exit 1
  fi

  TMP_ARCHIVE="$(mktemp)"
  TMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  LOGIN="$(github_login)"
  repo_options_output="$(repo_options "${LOGIN}")"
  REPO_SELECTION="$(select_from_list "repo" "${repo_options_output}" "Filter repos (leave blank to show all): ")"
  REPO_FULL_NAME="$(printf '%s\n' "${REPO_SELECTION}" | cut -f1)"
  OWNER="${REPO_FULL_NAME%%/*}"
  REPO="${REPO_FULL_NAME##*/}"
  FORMULA_NAME="$(printf '%s' "${REPO}" | tr '[:upper:]' '[:lower:]')"
  FORMULA_FILE="${FORMULA_DIR}/${FORMULA_NAME}.rb"

  if [[ -f "${FORMULA_FILE}" ]]
  then
    echo "Formula already exists: ${FORMULA_FILE}"
    exit 1
  fi

  ALL_TAGS="$(repo_tags "${OWNER}" "${REPO}")"
  if [[ -z "${ALL_TAGS:-}" ]]
  then
    echo "Could not find any tags for ${OWNER}/${REPO}"
    exit 1
  fi

  SELECTED_TAG="$(select_from_list "tag" "${ALL_TAGS}" "Filter tags (leave blank to show all): ")"
  ARCHIVE_URL="https://github.com/${OWNER}/${REPO}/archive/refs/tags/$(url_encode "${SELECTED_TAG}").tar.gz"

  curl -fsSL "${ARCHIVE_URL}" -o "${TMP_ARCHIVE}"
  SHA256="$(shasum -a 256 "${TMP_ARCHIVE}" | awk '{print $1}')"
  tar -xzf "${TMP_ARCHIVE}" -C "${TMP_DIR}"
  SOURCE_DIR="$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

  if [[ -z "${SOURCE_DIR:-}" ]]
  then
    echo "Could not unpack source archive for ${OWNER}/${REPO}"
    exit 1
  fi

  detect_build_strategy "${SOURCE_DIR}"

  repo_metadata_output="$(repo_metadata "${OWNER}" "${REPO}")"
  IFS=$'\t' read -r DESCRIPTION LICENSE_ID <<<"${repo_metadata_output}"

  if [[ -z "${DESCRIPTION}" ]]
  then
    DESCRIPTION="${REPO} command-line tool"
  fi

  CLASS_NAME="$(formula_class_name "${FORMULA_NAME}")"
  DESCRIPTION_LITERAL="$(ruby_single_quoted_string "${DESCRIPTION}")"
  HOMEPAGE_LITERAL="$(ruby_single_quoted_string "https://github.com/${OWNER}/${REPO}")"
  ARCHIVE_URL_LITERAL="$(ruby_single_quoted_string "${ARCHIVE_URL}")"
  SHA256_LITERAL="$(ruby_single_quoted_string "${SHA256}")"
  BINARY_LITERAL="$(ruby_single_quoted_string "${BINARY_NAME}")"

  LICENSE_LINE=""
  if [[ -n "${LICENSE_ID}" ]]
  then
    LICENSE_LINE="  license $(ruby_single_quoted_string "${LICENSE_ID}")"
  fi

  formula_contents "${CLASS_NAME}" "${DESCRIPTION_LITERAL}" "${HOMEPAGE_LITERAL}" "${ARCHIVE_URL_LITERAL}" "${SHA256_LITERAL}" "${LICENSE_LINE}" "${BINARY_LITERAL}" >"${FORMULA_FILE}"

  echo "Created ${FORMULA_FILE}"
  echo "Repo:    ${OWNER}/${REPO}"
  echo "Tag:     ${SELECTED_TAG}"
  echo "Build:   ${BUILD_SYSTEM}"
  echo "Binary:  ${BINARY_NAME}"
  echo "URL:     ${ARCHIVE_URL}"
  echo "SHA256:  ${SHA256}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]
then
  main "$@"
fi

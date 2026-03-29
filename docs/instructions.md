# AI Agent Instructions: Shell Scripts in This Tap

Shell scripts in this repository are linted with `brew style .`, which runs
both **shellcheck** and **shfmt**. Every script must pass with zero offenses
before being committed.

Run the linter at any time:

```bash
brew style .
```

Auto-apply shfmt formatting fixes (does not fix shellcheck issues):

```bash
brew style --fix .
```

---

## Rules enforced by `brew style .`

### 1. Use `[[ ]]` for all tests (SC2292)

Homebrew scripts target Bash. Always use `[[ ]]` instead of `[ ]`.

```bash
# ✅
if [[ $# -ne 1 ]]
then

# ❌
if [ $# -ne 1 ]; then
```

### 2. Always brace variable references (SC2250)

Wrap every variable expansion in `${}`, even when not strictly required.

```bash
# ✅
echo "${FORMULA_NAME}"
cd "${FORMULA_DIR}"

# ❌
echo "$FORMULA_NAME"
cd "$FORMULA_DIR"
```

### 3. Always double-quote variable references (SC2248)

Quote every variable expansion to prevent word-splitting and glob expansion.

```bash
# ✅
if [[ "${FZF_EXIT}" -ne 0 ]]

# ❌
if [[ $FZF_EXIT -ne 0 ]]
```

### 4. `if`/`while`/`for`: put `then`/`do` on its own line (shfmt)

```bash
# ✅
if [[ -z "${FOO}" ]]
then
  ...
fi

while true
do
  ...
done

# ❌
if [[ -z "${FOO}" ]]; then
while true; do
```

### 5. Here-strings: no space before `<<<` (shfmt)

```bash
# ✅
while IFS= read -r line
do
  ...
done <<<"${VARIABLE}"

# ❌
done <<< "$VARIABLE"
```

### 6. Redirections: no space before `>` or `>>` (shfmt)

```bash
# ✅
command >"${OUTPUT_FILE}"

# ❌
command > "${OUTPUT_FILE}"
```

### 7. End files with a trailing newline

Every shell script must end with a newline character. Most editors do this
automatically; verify with `cat -A script.sh | tail -1` — the last line
should end with `$`.

---

## Handling `set -e` and commands that may return non-zero

With `set -euo pipefail` active, any command that exits non-zero terminates
the script immediately — including interactive tools like `fzf` when the user
cancels. Handle this explicitly:

```bash
set +e
CHOSEN=$(some-interactive-command)
EXIT_CODE=$?
set -e
if [[ "${EXIT_CODE}" -ne 0 ]] || [[ -z "${CHOSEN:-}" ]]
then
  echo "Aborted."
  exit 1
fi
```

## Safe user-input filtering with grep

When passing user-supplied input to `grep`, always use `-F` (literal match)
and `--` to prevent the filter string from being interpreted as a regex or as
grep options:

```bash
FILTERED=$(echo "${ALL_TAGS}" | grep -iF -- "${FILTER}" || true)
```

---

## Quick checklist before committing a script

- [ ] `brew style .` exits 0 with "no offenses detected"
- [ ] All tests use `[[ ]]`
- [ ] All variable references use `"${VAR}"`
- [ ] `then`/`do` are on their own lines
- [ ] No spaces around `<<<` or before output redirections
- [ ] File ends with a trailing newline

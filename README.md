# SebastianKuehl Tap

## How do I install these formulae?

`brew install sebastiankuehl/tap/<formula>`

Or `brew tap sebastiankuehl/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "sebastiankuehl/tap"
brew "<formula>"
```

## Updating a formula

Use `update-formula.sh` to bump a formula to the latest GitHub release. It reads the `homepage` field from the formula file, fetches the latest tag from that repo, downloads the archive, recomputes the SHA256, and updates `url` and `sha256` in place.

```bash
./update-formula.sh <formula-name>
```

**Example:**

```bash
./update-formula.sh my-tool
```

The script requires the formula's `homepage` to be a GitHub repository URL (e.g. `https://github.com/owner/repo`). After running, review the diff and commit the changes.

## Adding a formula

Use `add-formula.sh` to select one of your public GitHub repositories, choose a tag, and generate a new formula in `Formula/`.

```bash
./add-formula.sh
```

The script currently supports:

- Rust repos with a `Cargo.toml` at the repo root
- Go repos with a `go.mod` and either a single root `main` package or exactly one `cmd/*` binary

It aborts for unsupported or ambiguous layouts instead of guessing an install block.

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

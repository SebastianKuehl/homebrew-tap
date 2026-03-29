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

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

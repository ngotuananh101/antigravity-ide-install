# Antigravity CLI Installer

A Bash script to automatically install/update **Antigravity CLI** on Linux.

## What the script does

1. Calls the `releases` API to get the latest version (`version` + `execution_id`).
2. Compares it against the currently installed version (tracked in a local marker file).
3. If a newer version is available → downloads the tarball matching your CPU architecture (`x64` or `arm`), extracts it, and creates a symlink on your `PATH`.
4. If already up to date → exits without doing anything.

## Requirements

- Linux (x86_64 or aarch64/arm64)
- Commands: `curl`, `wget`, `tar`, `grep`, `find`

## How to run

### Option 1 — Download and run directly

```bash
chmod +x install.sh
./install.sh
```

### Option 2 — Run without saving the file (if hosted on GitHub/raw)

```bash
curl -fsSL https://raw.githubusercontent.com/ngotuananh101/antigravity-ide-install/refs/heads/main/install.sh | bash
```

## Install locations

| Component | Path |
|---|---|
| Install directory | `~/.local/share/AntigravityIDE` |
| Executable symlink | `~/.local/bin/antigravity-ide` |
| Installed-version marker | `~/.local/share/AntigravityIDE/.installed_version` |

After installing, make sure `~/.local/bin` is on your `PATH`. If it isn't, add this to `~/.profile` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then restart your terminal or run `source ~/.bashrc`.

## Verify the install

```bash
antigravity --version
```

## Updating to a newer version

Just re-run the script — it will detect the new version and reinstall:

```bash
./install.sh
```

## Troubleshooting

**Error: "Could not find executable 'antigravity'"**

The tarball's internal layout may differ from what's expected. Inspect it manually:

```bash
tar -tzf /tmp/antigravity-*.tar.gz | head -30
```

Then adjust the `BIN_NAME` variable in the script (or the `find` logic) to match the actual executable's name/path.

**Download fails (`wget` error)**

Check connectivity to `edgedl.me.gvt1.com`, or try again — the download URL depends on the `execution_id`, which changes with each release.

## Uninstall

```bash
rm -rf ~/.local/share/AntigravityIDE
rm -f ~/.local/bin/antigravity-ide
```

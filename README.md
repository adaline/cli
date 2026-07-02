# Adaline CLI

The official command-line interface for [Adaline](https://adaline.ai) — manage prompts, datasets,
evaluators, evaluations (`eval`), deployments, providers, models, projects, and logs from your terminal.

This repository hosts the **prebuilt, standalone binaries and installers**. They bundle their own
runtime, so **no Node.js is required**. (Source lives in Adaline's SDK monorepo.)

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/adaline/cli/main/install.sh | sh
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/adaline/cli/main/install.ps1 | iex"
```

Verify the install:

```bash
adaline --version
adaline --help
```

The CLI is also available under the short alias **`adx`** — `adx` and `adaline` are
interchangeable (e.g. `adx --help`).

## Supported platforms

| OS | Architectures |
|---|---|
| macOS | Apple Silicon (arm64), Intel (x64) |
| Linux | x86_64 (x64), ARM (arm64) |
| Windows | x64 |

## Install options

The installers honor these environment variables:

| Variable | Default | Description |
|---|---|---|
| `ADALINE_VERSION` | `latest` | Version/tag to install (e.g. `0.1.0`). |
| `ADALINE_INSTALL_DIR` | `~/.local/bin` (Unix) · `%LOCALAPPDATA%\Adaline\bin` (Windows) | Where to install the binary. |
| `ADALINE_REPO` | `adaline/cli` | `owner/repo` to download release assets from. |

Example — pin a specific version on macOS/Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/adaline/cli/main/install.sh | ADALINE_VERSION=0.1.0 sh
```

## Updating

Once installed, the CLI updates itself — no need to re-run the installer:

```bash
adaline upgrade            # update to the latest release
adaline upgrade --check    # report whether an update is available (no install)
adaline upgrade --to 0.2.0 # switch to a specific version (up or down)
```

`upgrade` downloads the matching binary for your platform from the same release, verifies its
checksum, and replaces the running binary in place (refreshing the `adx` alias too).

## Verifying downloads

Every release publishes a `SHA256SUMS` file alongside the binaries; the installers verify the
downloaded binary against it automatically. To check a manual download:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

## Uninstall

Delete the binaries (and, on Windows, remove the install dir from your user `PATH`):

```bash
rm "$(command -v adaline)" "$(command -v adx)"
```

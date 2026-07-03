# Adaline CLI

The official command-line interface for [Adaline](https://adaline.ai). Manage your prompts,
datasets, evaluators, evaluations, deployments, providers, models, projects, and observability
logs from your terminal.

Standalone binaries — no Node.js or other dependencies required.

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

The CLI is also available under the short alias `adx` — `adx` and `adaline` are interchangeable.

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
| `ADALINE_VERSION` | `latest` | Version to install (e.g. `0.1.0`). |
| `ADALINE_INSTALL_DIR` | `~/.local/bin` (Unix) · `%LOCALAPPDATA%\Adaline\bin` (Windows) | Where to install the binary. |

Example — pin a specific version on macOS/Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/adaline/cli/main/install.sh | ADALINE_VERSION=0.1.0 sh
```

## Updating

The CLI updates itself in place — no need to re-run the installer:

```bash
adaline upgrade            # update to the latest release
adaline upgrade --check    # report whether an update is available (no install)
adaline upgrade --to 0.2.0 # switch to a specific version (up or down)
```

## Verifying downloads

Every release publishes a `SHA256SUMS` file alongside the binaries, and the installers verify each
download against it automatically. To check a manual download:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

## Uninstall

Delete the binaries (and, on Windows, remove the install dir from your user `PATH`):

```bash
rm "$(command -v adaline)" "$(command -v adx)"
```

# Kaptive APT Repository

APT package repository for Kaptive components.

Installing the `kaptive-signage` metapackage pulls in all available Kaptive components.

## Adding the repository (client setup)

```bash
# Import the signing key
curl -fsSL https://kaptive-signage.github.io/apt/key.gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/kaptive.gpg

# Add the repository (replace DIST with your distribution, e.g. bookworm)
echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/kaptive.gpg] https://kaptive-signage.github.io/apt DIST main' | sudo tee /etc/apt/sources.list.d/kaptive.list

# Install
sudo apt-get update
sudo apt-get install kaptive-signage
```

## Repository structure

Each distribution is a root-level folder with its own packages and version:

```
bookworm/
  VERSION              # semver, e.g. 0.1.23
  pool/main/           # .deb packages for this distribution
bookworm-staging/      # (example — add when needed)
  VERSION
  pool/main/
```

To add a new distribution, create a folder with a `VERSION` file and a `pool/main/` directory containing your `.deb` files.

## Publishing packages

1. Copy `.deb` files into `<distribution>/pool/main/` and commit.
2. Bump the version in `<distribution>/VERSION`, commit and push to `main`.

The GitHub Action triggers when any `*/VERSION` file changes. It discovers all distributions automatically, rebuilds the repository metadata and metapackages, and deploys to GitHub Pages.

You can also trigger a rebuild manually from **Actions > Update APT Repository > Run workflow**.

## Repository setup

### GitHub Pages

Go to **Settings > Pages** and set the source to **GitHub Actions**.

### Secrets

Add the following secrets under **Settings > Secrets and variables > Actions**:

| Secret | Value |
|---|---|
| `GPG_PRIVATE_KEY` | ASCII-armored private key (`gpg --armor --export-secret-keys <key-id>`) |
| `GPG_KEY_ID` | Key ID or email associated with the GPG key |

### Generating a GPG key

If you don't have one yet:

```bash
gpg --full-generate-key
```

# Kaptive APT Repository

APT package repository for Kaptive components.

Installing the `kaptive` metapackage pulls in all available Kaptive components.

## Adding the repository (client setup)

```bash
# Import the signing key
curl -fsSL https://kaptive-signage.github.io/apt/key.gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/kaptive.gpg

# Add the repository
echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/kaptive.gpg] https://kaptive-signage.github.io/apt bookworm main' | sudo tee /etc/apt/sources.list.d/kaptive.list

# Install
sudo apt-get update
sudo apt-get install kaptive
```

## Publishing packages

1. Copy `.deb` files into `pool/main/`.
2. Commit and push to `main`.

The GitHub Action will automatically rebuild the repository metadata, generate the `kaptive` metapackage, and deploy to GitHub Pages.

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

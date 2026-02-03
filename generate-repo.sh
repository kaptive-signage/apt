#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
DIST="bookworm"
COMPONENT="main"
ARCH="arm64"
ORIGIN="Kaptive"
LABEL="Kaptive"
DESCRIPTION="Kaptive APT Repository"
METAPKG_NAME="kaptive-signage"
METAPKG_DESCRIPTION="Metapackage that installs all Kaptive components"
METAPKG_MAINTAINER="Kaptive <info@kaptive.ch>"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
POOL_DIR="${REPO_DIR}/pool/${COMPONENT}"
PUBLIC_DIR="${REPO_DIR}/public"
DISTS_DIR="${PUBLIC_DIR}/dists/${DIST}"
BINARY_DIR="${DISTS_DIR}/${COMPONENT}/binary-${ARCH}"
PUBLIC_POOL="${PUBLIC_DIR}/pool/${COMPONENT}"

GPG_KEY_ID="${1:?Usage: $0 <gpg-key-id>}"

# --- Helpers ---
die() { echo "ERROR: $*" >&2; exit 1; }

# --- Generate directory listing HTML ---
generate_index_html() {
    local dir="$1"
    local rel_path="${dir#"${PUBLIC_DIR}"}"
    rel_path="/${rel_path#/}"

    local html="${dir}/index.html"
    cat > "$html" <<HEADER
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Index of ${rel_path}</title>
<style>
  body { font-family: monospace; margin: 2em; }
  h1 { font-size: 1.2em; }
  table { border-collapse: collapse; }
  td { padding: 0.2em 1em; }
  a { text-decoration: none; }
  a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>Index of ${rel_path}</h1>
<table>
HEADER

    # Parent directory link
    if [[ "$rel_path" != "/" ]]; then
        echo '<tr><td><a href="../">../</a></td><td></td><td></td></tr>' >> "$html"
    fi

    # List directories first, then files
    for entry in "$dir"/*/; do
        [[ -d "$entry" ]] || continue
        local name
        name="$(basename "$entry")/"
        echo "<tr><td><a href=\"${name}\">${name}</a></td><td></td><td></td></tr>" >> "$html"
    done

    for entry in "$dir"/*; do
        [[ -f "$entry" ]] || continue
        local name size
        name="$(basename "$entry")"
        [[ "$name" == "index.html" ]] && continue
        size=$(wc -c < "$entry" | tr -d ' ')
        echo "<tr><td><a href=\"${name}\">${name}</a></td><td>${size}</td></tr>" >> "$html"
    done

    cat >> "$html" <<FOOTER
</table>
</body>
</html>
FOOTER

    # Recurse into subdirectories
    for entry in "$dir"/*/; do
        [[ -d "$entry" ]] || continue
        generate_index_html "${entry%/}"
    done
}

# --- Build kaptive metapackage ---
build_metapackage() {
    local tmp_dir deps_list=""

    # Collect package names from all .deb files in the pool (excluding the metapackage itself)
    for deb in "${POOL_DIR}"/*.deb; do
        local pkg_name
        pkg_name=$(dpkg-deb --field "$deb" Package)
        [[ "$pkg_name" == "$METAPKG_NAME" ]] && continue
        if [[ -n "$deps_list" ]]; then
            deps_list+=", "
        fi
        deps_list+="$pkg_name"
    done

    if [[ -z "$deps_list" ]]; then
        die "No dependency packages found in pool/${COMPONENT}/"
    fi

    echo "Metapackage dependencies: ${deps_list}"

    # Determine version from current date
    local version
    version="$(date +%Y.%m.%d)"

    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/DEBIAN"

    cat > "${tmp_dir}/DEBIAN/control" <<EOF
Package: ${METAPKG_NAME}
Version: ${version}
Architecture: ${ARCH}
Maintainer: ${METAPKG_MAINTAINER}
Depends: ${deps_list}
Section: metapackages
Priority: optional
Description: ${METAPKG_DESCRIPTION}
EOF

    local deb_name="${METAPKG_NAME}_${version}_${ARCH}.deb"
    dpkg-deb --build "$tmp_dir" "${POOL_DIR}/${deb_name}"
    rm -rf "$tmp_dir"

    echo "Built ${deb_name} (version ${version})"
}

# --- Main ---
main() {
    # Verify tools
    for cmd in dpkg-deb dpkg-scanpackages gzip gpg; do
        command -v "$cmd" &>/dev/null || die "Missing: ${cmd}. Install dpkg-dev."
    done

    # Verify GPG key
    gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1 || die "GPG key '${GPG_KEY_ID}' not found"

    # Check for .deb files (excluding any prior metapackage)
    shopt -s nullglob
    local debs=("${POOL_DIR}"/*.deb)
    shopt -u nullglob

    if (( ${#debs[@]} == 0 )); then
        die "No .deb packages found in pool/${COMPONENT}/. Copy your .deb files there first."
    fi

    # Remove stale metapackage before rebuilding
    rm -f "${POOL_DIR}/${METAPKG_NAME}_"*.deb

    echo "==> Building kaptive-signage metapackage"
    build_metapackage

    # Prepare public directory
    rm -rf "$PUBLIC_DIR"
    mkdir -p "$BINARY_DIR" "$PUBLIC_POOL"
    cp "${POOL_DIR}"/*.deb "$PUBLIC_POOL/"

    # Generate Packages index
    echo "==> Generating Packages index"
    (cd "$PUBLIC_DIR" && dpkg-scanpackages --arch "$ARCH" "pool/${COMPONENT}" /dev/null) > "${BINARY_DIR}/Packages"
    gzip -9c "${BINARY_DIR}/Packages" > "${BINARY_DIR}/Packages.gz"

    local pkg_count
    pkg_count=$(grep -c "^Package:" "${BINARY_DIR}/Packages" || true)
    echo "Indexed ${pkg_count} package(s)"

    # Generate Release file
    echo "==> Generating Release file"
    local packages_size packages_gz_size
    local packages_md5 packages_gz_md5
    local packages_sha256 packages_gz_sha256

    packages_size=$(wc -c < "${BINARY_DIR}/Packages" | tr -d ' ')
    packages_gz_size=$(wc -c < "${BINARY_DIR}/Packages.gz" | tr -d ' ')
    packages_md5=$(md5sum "${BINARY_DIR}/Packages" | awk '{print $1}')
    packages_gz_md5=$(md5sum "${BINARY_DIR}/Packages.gz" | awk '{print $1}')
    packages_sha256=$(sha256sum "${BINARY_DIR}/Packages" | awk '{print $1}')
    packages_gz_sha256=$(sha256sum "${BINARY_DIR}/Packages.gz" | awk '{print $1}')

    cat > "${DISTS_DIR}/Release" <<EOF
Origin: ${ORIGIN}
Label: ${LABEL}
Suite: ${DIST}
Codename: ${DIST}
Architectures: ${ARCH}
Components: ${COMPONENT}
Description: ${DESCRIPTION}
Date: $(date -Ru)
MD5Sum:
 ${packages_md5} ${packages_size} ${COMPONENT}/binary-${ARCH}/Packages
 ${packages_gz_md5} ${packages_gz_size} ${COMPONENT}/binary-${ARCH}/Packages.gz
SHA256:
 ${packages_sha256} ${packages_size} ${COMPONENT}/binary-${ARCH}/Packages
 ${packages_gz_sha256} ${packages_gz_size} ${COMPONENT}/binary-${ARCH}/Packages.gz
EOF

    # Sign
    echo "==> Signing repository"
    gpg --default-key "$GPG_KEY_ID" --armor --detach-sign --output "${DISTS_DIR}/Release.gpg" --yes "${DISTS_DIR}/Release"
    gpg --default-key "$GPG_KEY_ID" --armor --clearsign --output "${DISTS_DIR}/InRelease" --yes "${DISTS_DIR}/Release"

    # Export public key for clients
    gpg --armor --export "$GPG_KEY_ID" > "${PUBLIC_DIR}/key.gpg.asc"

    # Generate directory listings
    echo "==> Generating directory listings"
    generate_index_html "$PUBLIC_DIR"

    echo ""
    echo "Done. public/ directory ready for deployment."
    echo ""
    echo "--- Client setup ---"
    echo "  curl -fsSL https://<owner>.github.io/kaptive-apt-repo/key.gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/kaptive.gpg"
    echo "  echo 'deb [arch=${ARCH} signed-by=/usr/share/keyrings/kaptive.gpg] https://<owner>.github.io/kaptive-apt-repo ${DIST} ${COMPONENT}' | sudo tee /etc/apt/sources.list.d/kaptive.list"
    echo "  sudo apt-get update && sudo apt-get install ${METAPKG_NAME}"
}

main "$@"

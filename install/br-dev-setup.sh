#!/usr/bin/env bash
set -euo pipefail

SCOPE="${BR_NPM_SCOPE:-businessrate}"
REGISTRY="https://npm.pkg.github.com"
HOSTNAME="${BR_GH_HOSTNAME:-github.com}"
PACKAGES_SCOPES="${BR_PACKAGES_SCOPE:-read:packages}"

echo "==> BusinessRate dev setup (GitHub Packages)"
echo "    npm scope: @$SCOPE"
echo "    registry:  $REGISTRY"
echo "    github:    $HOSTNAME"
echo

# ---- Preconditions ----
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is not installed."
  echo "Install it (macOS): brew install gh"
  echo "Install it (other): https://cli.github.com/"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is not installed (or not on PATH)."
  echo "Install Node.js (macOS): brew install node"
  exit 1
fi

# ---- GitHub auth ----
echo "==> Checking GitHub CLI auth..."
if gh auth status --hostname "$HOSTNAME" >/dev/null 2>&1; then
  echo "    gh is already authenticated."
else
  echo "==> Launching browser auth via 'gh auth login'..."
  gh auth login --hostname "$HOSTNAME"
fi

# ---- Ensure gh token has required scopes ----
echo
echo "==> Ensuring GitHub token scopes include: ${PACKAGES_SCOPES}"
# IMPORTANT: curl|bash is non-interactive; gh requires --hostname in that case.
gh auth refresh --hostname "$HOSTNAME" --scopes "$PACKAGES_SCOPES" >/dev/null

# ---- Configure npm ----
echo
echo "==> Configuring npm…"
npm config set "@${SCOPE}:registry" "${REGISTRY}" >/dev/null

TOKEN="$(gh auth token --hostname "$HOSTNAME")"
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: 'gh auth token' returned an empty token."
  exit 1
fi

npm config set "//npm.pkg.github.com/:_authToken" "${TOKEN}" >/dev/null

# Optional; don't fail if npm rejects this key on some versions.
npm config set "always-auth" "true" >/dev/null 2>&1 || true

echo
echo "==> Verifying auth against GitHub Packages…"
WHOAMI="$(npm whoami --registry="${REGISTRY}" 2>/dev/null || true)"
if [[ -z "${WHOAMI}" ]]; then
  echo "ERROR: npm auth verification failed."
  echo
  echo "Debug:"
  echo "  gh auth status --hostname=${HOSTNAME} -t"
  echo "  npm whoami --registry=${REGISTRY}"
  echo "  npm config get @${SCOPE}:registry"
  echo "  npm config get //npm.pkg.github.com/:_authToken"
  exit 1
fi

echo "✅ Success! Authenticated to GitHub Packages as: ${WHOAMI}"
echo
echo "Done. You can now install scoped packages like:"
echo "  npm i @${SCOPE}/shared-core"
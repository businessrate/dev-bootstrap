#!/usr/bin/env bash
set -euo pipefail

# BusinessRate GitHub Packages bootstrap
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/businessrate/dev-bootstrap/main/install/br-dev-setup.sh | bash
#
# Optional:
#   BR_NPM_SCOPE=businessrate bash <(curl -fsSL ...)
#   BR_PACKAGES_SCOPE=read:packages bash <(curl -fsSL ...)
#   BR_PACKAGES_SCOPE=read:packages,write:packages bash <(curl -fsSL ...)

SCOPE="${BR_NPM_SCOPE:-businessrate}"
REGISTRY="https://npm.pkg.github.com"
PACKAGES_SCOPES="${BR_PACKAGES_SCOPE:-read:packages}"

echo "==> BusinessRate dev setup (GitHub Packages)"
echo "    npm scope: @$SCOPE"
echo "    registry:  $REGISTRY"
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

# ---- GitHub auth (browser) ----
echo "==> Checking GitHub CLI auth..."
if gh auth status >/dev/null 2>&1; then
  echo "    gh is already authenticated."
else
  echo "==> Launching browser auth via 'gh auth login'..."
  gh auth login
fi

# ---- Ensure gh token has required scopes ----
echo
echo "==> Ensuring GitHub token scopes include: ${PACKAGES_SCOPES}"
# Refresh token scopes; if SSO is enforced, gh will guide through authorization.
gh auth refresh -s "${PACKAGES_SCOPES}" >/dev/null

# ---- Configure npm ----
echo
echo "==> Configuring npm…"
# 1) Route @businessrate/* to GitHub Packages
npm config set "@${SCOPE}:registry" "${REGISTRY}" >/dev/null

# 2) Write auth token for npm.pkg.github.com
# IMPORTANT: npm config set does NOT read stdin; we must pass the token as an argument.
TOKEN="$(gh auth token)"
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: 'gh auth token' returned an empty token."
  exit 1
fi
npm config set "//npm.pkg.github.com/:_authToken" "${TOKEN}" >/dev/null

# Optional: always-auth improves reliability for some setups, but don't fail if npm dislikes it.
npm config set "always-auth" "true" >/dev/null 2>&1 || true

echo
echo "==> Verifying auth against GitHub Packages…"
WHOAMI="$(npm whoami --registry="${REGISTRY}" 2>/dev/null || true)"
if [[ -z "${WHOAMI}" ]]; then
  echo "ERROR: npm auth verification failed."
  echo
  echo "Debug:"
  echo "  gh auth status -t"
  echo "  npm whoami --registry=${REGISTRY}"
  echo "  npm config get @${SCOPE}:registry"
  echo "  npm config get //npm.pkg.github.com/:_authToken"
  exit 1
fi

echo "✅ Success! Authenticated to GitHub Packages as: ${WHOAMI}"
echo
echo "Done. You can now install scoped packages like:"
echo "  npm i @${SCOPE}/shared-core"
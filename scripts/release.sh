#!/usr/bin/env bash
set -e

BUMP=${1:-patch}

case "$BUMP" in
  patch|minor|major) ;;
  *)
    echo "Usage: $0 [patch|minor|major]" >&2
    exit 1
    ;;
esac

LATEST=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
LATEST=${LATEST:-v0.0.0}

VERSION="${LATEST#v}"
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}"

echo "${LATEST} → ${NEW_TAG}"
git tag "$NEW_TAG"
git push origin "$NEW_TAG"
echo "Released ${NEW_TAG}"

#!/usr/bin/env bash
# Downloads Meta's Muse Gadget SDK at the version this guide was tested with
# and applies this repo's patch: the Waveshare ESP32-S3-Touch-AMOLED-1.8 V2
# board, spoken replies with OpenAI, a 60 s voice note limit, and a
# forgiving talk button.
#
#   ./scripts/setup.sh
#
# Safe to run again: it skips steps that are already done.
set -euo pipefail

MUSE_REPO="https://github.com/facebookincubator/muse-gadget-sdk.git"
MUSE_COMMIT="b1a3822995a51c0203cd1f3d72c1c656b8c3e620"   # 2026-10-03, the tested version

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="$root/muse-gadget-sdk"
patch="$root/patches/muse-waveshare-s3-18.patch"

if [[ ! -d "$sdk/.git" ]]; then
  echo "Downloading the Muse Gadget SDK..."
  git clone --quiet "$MUSE_REPO" "$sdk"
fi

cd "$sdk"
if git apply --reverse --check "$patch" 2>/dev/null; then
  echo "Patch already applied. Nothing to do."
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "muse-gadget-sdk/ has local changes. Commit or remove them, then run this again." >&2
  exit 1
fi

git checkout --quiet "$MUSE_COMMIT"
git apply "$patch"
echo "Done. The SDK is in muse-gadget-sdk/ with the AMOLED 1.8 V2 board added."
echo "Next: ./scripts/configure.sh"

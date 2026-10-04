#!/usr/bin/env bash
# Asks for your Muse SDK token and (optionally) an OpenAI API key, saves them
# in the build's own settings file, and builds the firmware.
#
#   ./scripts/configure.sh            # Waveshare ESP32-S3-Touch-AMOLED-1.8 V2
#   ./scripts/configure.sh s3         # any board alias Muse's board.sh knows
#
# What you type is hidden. Both secrets end up only in
# muse-gadget-sdk/esp32/build-muse-<board>/sdkconfig, which git ignores.
# They are compiled into the firmware, so anyone holding the device could
# read them out: give the OpenAI key a low spending limit.
set -euo pipefail

board="${1:-s318}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
esp32="$root/muse-gadget-sdk/esp32"

if [[ ! -x "$esp32/tools/muse/board.sh" ]]; then
  echo "Run ./scripts/setup.sh first." >&2
  exit 1
fi

profile="$(sed -n "s/^ *$board) *profile=\([^;]*\);.*/\1/p" "$esp32/tools/muse/board.sh" | head -1 | tr -d ' ')"
if [[ -z "$profile" ]]; then
  echo "Unknown board '$board'. See the case list in $esp32/tools/muse/board.sh." >&2
  exit 1
fi
cfg="$esp32/build-muse-$profile/sdkconfig"

build() {
  echo "Building (the first build takes a few minutes)..."
  if ! "$esp32/tools/muse/board.sh" build "$board" >/dev/null 2>&1; then
    echo "Build failed. See /tmp/muse_build_$board.log" >&2
    exit 1
  fi
}

[[ -f "$cfg" ]] || build

# Replaces KEY's line in the build's sdkconfig with KEY="value" (value from the environment).
save() {
  KEY="$1" VALUE="$2" python3 - "$cfg" <<'EOF'
import os, re, sys
path, key, value = sys.argv[1], os.environ["KEY"], os.environ["VALUE"].strip()
text = open(path).read()
line = '%s="%s"' % (key, value)
pattern = r'^(# )?%s(=.*| is not set)$' % re.escape(key)
if re.search(pattern, text, flags=re.M):
    text = re.sub(pattern, lambda m: line, text, flags=re.M)
else:
    text += "\n" + line + "\n"
open(path, "w").write(text)
EOF
}

# Turns a yes/no setting on: KEY=y.
save_flag() {
  KEY="$1" python3 - "$cfg" <<'EOF2'
import os, re, sys
path, key = sys.argv[1], os.environ["KEY"]
text = open(path).read()
pattern = r'^(# )?%s(=.*| is not set)$' % re.escape(key)
line = key + "=y"
if re.search(pattern, text, flags=re.M):
    text = re.sub(pattern, lambda m: line, text, flags=re.M)
else:
    text += "\n" + line + "\n"
open(path, "w").write(text)
EOF2
}

read -r -s -p "Muse SDK token (starts with mgst_, from gadgets.muse.ai > Account > SDK tokens): " token
echo
if [[ ! "$token" =~ ^mgst_[A-Za-z0-9_-]{43}$ ]]; then
  echo "That doesn't look like a Muse SDK token (mgst_ plus 43 letters and numbers). Copy it again. Nothing changed." >&2
  exit 1
fi
save CONFIG_GADGET_SDK_TOKEN "$token"
unset token

read -r -s -p "OpenAI API key for a spoken voice (starts with sk-), or press Return to skip: " key
echo
if [[ -n "$key" ]]; then
  if [[ "$key" != sk-* ]]; then
    echo "That doesn't look like an OpenAI key. Skipping the voice." >&2
  else
    save CONFIG_MUSE_TTS_OPENAI_KEY "$key"
    # api.openai.com's certificate chain is cross-signed; ESP-IDF needs this to trust it.
    save_flag CONFIG_MBEDTLS_CERTIFICATE_BUNDLE_CROSS_SIGNED_VERIFY
    echo "Voice on."
  fi
fi
unset key

build
echo "Done. Plug in the board and run:"
echo "  cd muse-gadget-sdk/esp32 && tools/muse/board.sh flash $board"

#!/usr/bin/env bash
# Writes a placeholder GoogleService-Info.plist so the project builds and the app launches
# (for unit tests) without a real Firebase project. Push notifications will not work with it.
# Firebase validates the format at launch: API_KEY must be 39 chars starting with "A".
# Deliberately not "AIza...": that prefix makes GitHub secret scanning flag it as a Google API key.
# Existing files are left alone unless --force is given.
set -euo pipefail

dest="$(cd "$(dirname "$0")/.." && pwd)/ntfy/Assets/GoogleService-Info.plist"

if [[ -f "$dest" && "${1:-}" != "--force" ]]; then
    echo "$dest already exists, leaving it alone (use --force to overwrite)"
    exit 0
fi

cat > "$dest" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_KEY</key><string>A00000000000000000000000000000000000000</string>
    <key>GCM_SENDER_ID</key><string>000000000000</string>
    <key>BUNDLE_ID</key><string>io.heckel.ntfy</string>
    <key>PROJECT_ID</key><string>ntfy-dummy</string>
    <key>GOOGLE_APP_ID</key><string>1:000000000000:ios:0000000000000000</string>
</dict>
</plist>
EOF
echo "Wrote dummy $dest"

#!/usr/bin/env bash
# Lints the repo: Swift via SwiftLint, plus syntax checks for plists, JSON, XML and shell scripts.
# Used by CI and runnable locally. Exits non-zero if any check fails.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
git rev-parse --is-inside-work-tree >/dev/null || { echo "Not a git checkout"; exit 1; }
failed=0
section() { printf '\n== %s ==\n' "$1"; }
fail() { echo "FAIL: $1"; failed=1; }

# Tracked plus new (not ignored) files, so local runs also cover files not yet committed.
files() { git ls-files --cached --others --exclude-standard -- "$@" | sort -u | while read -r f; do [[ -f "$f" ]] && echo "$f"; done; }

section "SwiftLint"
if command -v swiftlint >/dev/null; then
    reporter="xcode"
    [[ -n "${GITHUB_ACTIONS:-}" ]] && reporter="github-actions-logging"
    swiftlint lint --quiet --reporter "$reporter" || fail "swiftlint"
else
    fail "swiftlint not installed (brew install swiftlint)"
fi

section "Property lists (plist, entitlements, pbxproj)"
while read -r f; do
    plutil -lint -s "$f" || fail "$f"
done < <(files '*.plist' '*.entitlements' '*.pbxproj')

section "JSON (emoji data, asset catalogs, Package.resolved)"
while read -r f; do
    jq empty "$f" 2>/dev/null || fail "$f is not valid JSON"
done < <(files '*.json' '*.resolved')

section "XML (schemes, Core Data model, workspace)"
while read -r f; do
    xmllint --noout "$f" || fail "$f"
done < <(files '*.xcscheme' '*.xcworkspacedata' '*.xcdatamodel/contents')

section "Shell scripts"
while read -r f; do
    bash -n "$f" || fail "$f"
    if command -v shellcheck >/dev/null; then
        shellcheck "$f" || fail "shellcheck $f"
    fi
done < <(files '*.sh')

section "GitHub workflows"
if command -v actionlint >/dev/null; then
    actionlint || fail "actionlint"
else
    echo "actionlint not installed, skipping (brew install actionlint)"
fi

echo
if [[ $failed -ne 0 ]]; then
    echo "Lint failed."
    exit 1
fi
echo "Lint passed."

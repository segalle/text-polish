#!/usr/bin/env bash
# Builds, installs to /Applications and relaunches Text Polish.
#
# An ad-hoc signed app gets a new identity on every build, and macOS keeps the Accessibility
# grant pinned to the old one: toggling the old entry off and on does not move it to the new
# build. So this script clears the stale grant; macOS then asks once for the new build.
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build-app.sh

for id in com.local.textpolish com.local.slackpolish; do
    osascript -e "quit app id \"$id\"" 2>/dev/null || true
done
pkill -x TextPolish 2>/dev/null || true
pkill -x SlackPolish 2>/dev/null || true
sleep 1

# Earlier versions were called Slack Polish.
if [ -d /Applications/SlackPolish.app ]; then
    rm -rf /Applications/SlackPolish.app
    tccutil reset Accessibility com.local.slackpolish >/dev/null 2>&1 || true
fi

rm -rf /Applications/TextPolish.app
cp -R build/TextPolish.app /Applications/TextPolish.app

if [ -z "${SIGN_IDENTITY:-}" ]; then
    tccutil reset Accessibility com.local.textpolish >/dev/null 2>&1 || true
    echo "Cleared the old Accessibility grant. Allow Text Polish when macOS asks."
fi

open /Applications/TextPolish.app

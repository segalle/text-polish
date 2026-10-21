#!/usr/bin/env bash
# Builds, installs to /Applications and relaunches Slack Polish.
#
# An ad-hoc signed app gets a new identity on every build, and macOS keeps the Accessibility
# grant pinned to the old one: toggling the old entry off and on does not move it to the new
# build. So this script clears the stale grant; macOS then asks once for the new build.
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/build-app.sh

osascript -e 'quit app id "com.local.slackpolish"' 2>/dev/null || true
pkill -x SlackPolish 2>/dev/null || true
sleep 1

rm -rf /Applications/SlackPolish.app
cp -R build/SlackPolish.app /Applications/SlackPolish.app

if [ -z "${SIGN_IDENTITY:-}" ]; then
    tccutil reset Accessibility com.local.slackpolish >/dev/null 2>&1 || true
    echo "Cleared the old Accessibility grant. Allow Slack Polish when macOS asks."
fi

open /Applications/SlackPolish.app

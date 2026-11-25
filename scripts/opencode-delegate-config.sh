#!/usr/bin/env sh
# Print a headless ("delegation") variant of an opencode.json: every permission
# rule set to "ask" becomes "deny", so `opencode run` stops and reports instead
# of waiting for a human (ADR-0038). Allow and deny rules are kept as they are.
#   scripts/opencode-delegate-config.sh opencode.json > ~/.config/opencode-delegate.json
set -eu
jq 'if .permission then .permission |= walk(if . == "ask" then "deny" else . end) else . end' "${1:-opencode.json}"

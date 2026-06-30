#!/usr/bin/env bash
# Rendered into a coder_script by the coder-anthropic-sandbox module.
# Runs at agent start with the ANTHROPIC_* env vars set by the module's
# coder_env resources. Exits 0 (idle) when no session is bound, so that
# workspaces built without dispatcher parameters (manual inspection,
# CI smoke) still succeed.
set -uo pipefail

DONE_FILE="${done_file}"
mkdir -p "$(dirname "$DONE_FILE")"
trap 'touch "$DONE_FILE"' EXIT

if [ -z "$${ANTHROPIC_SESSION_ID:-}" ]; then
	echo "No ANTHROPIC_SESSION_ID set; idling. The Coder dispatcher fills this in for sessions claimed from Anthropic."
	exit 0
fi

%{ if working_directory != "" ~}
cd "${working_directory}" || {
	echo "failed to cd into ${working_directory}" >&2
	exit 1
}
%{ endif ~}

echo "Starting Anthropic session $ANTHROPIC_SESSION_ID (work $ANTHROPIC_WORK_ID, env $ANTHROPIC_ENVIRONMENT_ID)"
${command}
status=$?
echo "Session $ANTHROPIC_SESSION_ID exited with status $status"
exit $status

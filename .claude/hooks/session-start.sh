#!/bin/bash
set -euo pipefail

# Don't run in local Claude Code sessions.
# Only "remote" i.e. Anthropic-cloud-hosted sessions via
# "Claude Code on the web":
#   https://code.claude.com/docs/en/claude-code-on-the-web
# (We don't want to e.g. clobber local Flutter-upstream work.)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# Halt if this session was started against the upstream repo instead
# of a personal fork.  The team workflow is fork + PR; any commits
# made here would be unpushable (or, worse, pushed to upstream).
origin_url=$(git config --get remote.origin.url || true)
case "$origin_url" in
  *zulip/zulip-flutter|*zulip/zulip-flutter.git)
    cat <<'EOF'
{
  "continue": false,
  "stopReason": "This session is on zulip/zulip-flutter (the upstream repo). The team workflow is to work on a personal fork and submit PRs. Start a new session, choosing your fork from the repo dropdown."
}
EOF
    exit 0
    ;;
esac

# shellcheck source=tools/lib/deps.sh
. tools/lib/deps.sh

flutter_tree=$(flutter_tree)

flutter channel main --no-cache-artifacts
# Equivalent to `flutter upgrade` minus the all-platforms precache.
# (Subsequent flutter commands will lazily precache what they need.)
git -C "${flutter_tree}" pull --ff-only
flutter pub get

# Override the commit.gpgsign=true that Anthropic sets in
# /root/.gitconfig in the Linux container.
# The signing key configured there is Claude's, not the developer's,
# so a "Verified" badge on GitHub would misattribute authorship.
# (Empirically in 2026-05, signing doesn't actually happen anyway,
# because the signing-key file is empty, but still.)
git config --local commit.gpgsign false

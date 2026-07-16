# Developing with Claude Code on the web

[Claude Code on the web][ccweb] runs each Claude session in an
Anthropic-hosted VM, cloned fresh from the repo. It's useful for
delegating tasks without tying up a local machine. This doc
describes how to set up a cloud environment for this repo.

For local development with Claude, see [claude.md](claude.md).
This cloud setup is one of several sandboxing options; see
[the comparison](claude.md#sandboxing) there.

[ccweb]: https://code.claude.com/docs/en/claude-code-on-the-web


## Setting up an environment

At [claude.ai/code][claude-code-web], create an environment for
**your fork** -- not the upstream repo. The team workflow is
fork + PR, and a SessionStart hook (see below) halts sessions
started on upstream, where commits would have nowhere good to go.

An environment is configured by filling in text fields in the
web UI:

- **Setup script**: paste this one line:

  ```bash
  tools/provision-cloud
  ```

  The script installs the needed system packages, sets up the
  Flutter SDK, warms the pub cache, and clones the Zulip server
  repo to `../zulip`. It's short; read it for the details.

  Note there's no automatic sync between the repo and this
  field: the platform rebuilds the environment cache when the
  field's text changes, so edits to `tools/provision-cloud`
  don't trigger a rebuild on their own. To force one, tweak the
  field, e.g. by adding or removing a blank line.

- **Network access**: "Trusted" (the default). The setup script
  needs to reach apt, GitHub, and pub.dev, and sessions need
  pub.dev and chat.zulip.org.

- **Environment variables**: none needed. In particular, leave
  `GH_TOKEN` and `GITHUB_TOKEN` unset: Anthropic's GitHub proxy
  then authenticates `gh` with your real GitHub credentials,
  which it holds outside the sandbox. (A token set here would
  be used instead of the proxy's authentication, so e.g. a
  read-only token would break `gh pr create`.)

[claude-code-web]: https://claude.ai/code


## How it works

The setup script runs once, as root, when the environment's
cache is first built; Anthropic then snapshots the filesystem
and starts later sessions from the snapshot. The cache is
rebuilt when the setup script or network settings change, and
when it expires after roughly seven days. Only the setup
script's work gets snapshotted -- anything downloaded during a
session (pub packages, Flutter artifacts) is not, which is why
the setup script warms those caches up front.

Each session then starts from a fresh clone of the repo, plus
that snapshot. A SessionStart hook in
[`.claude/settings.json`](../../.claude/settings.json),
[`tools/cloud-session-start`](../../tools/cloud-session-start),
finishes the job in each session:

- halts the session if it was started on upstream rather than
  a fork (see above);
- runs `flutter pub get` for the fresh clone (fast, thanks to
  the snapshot's warm pub cache), showing the output on failure
  so Claude can react. For example, since this repo tracks
  Flutter's `main` channel, the cached SDK can fall behind
  `pubspec.yaml`'s minimum Flutter version within the cache's
  lifetime; `flutter upgrade` fixes that.

The hook is a no-op outside cloud sessions (it checks
`CLAUDE_CODE_REMOTE`), so local and Lima-VM sessions are
unaffected.


## Known rough edges

As of 2026-07, Anthropic's docs don't state what directory the
setup script runs in. The `tools/provision-cloud` one-liner
assumes it's the repo checkout, as the docs' own example setup
scripts (like `npm install`) presuppose. If the environment's
setup log instead shows
`tools/provision-cloud: No such file or directory`, prefix the
setup script with a `cd` to wherever the log shows the checkout
landing.

The docs also don't state what user sessions run as, but
empirically (2026-05) it's root, same as the setup script, so
the snapshot's `~/flutter` and pub cache are usable in sessions.


## Trust model

Unlike the [Lima setup](lima.md#trust-model), where pushing is
reserved for the host, cloud sessions are designed to push:
Anthropic's GitHub proxy holds your real credentials outside
the sandbox, and hands the session a scoped credential that can
push only to the session's own working branch. Review anything
it produces like any other contributor's work, per Zulip's
[AI use policy][ai-policy].

[ai-policy]: https://zulip.readthedocs.io/en/latest/contributing/contributing.html#ai-use-policy-and-guidelines

# Developing with Claude Code on the web

[Claude Code on the web][ccweb] runs each Claude session in an
Anthropic-hosted VM, cloned fresh from the repo. It's useful for
delegating tasks without tying up a local machine. Sessions can
be started and steered from [claude.ai/code][claude-code-web]
in a browser, or from the Claude mobile app's Code tab (see the
[quickstart][ccweb-quickstart]). This doc covers using it for
this repo.

For local development with Claude, see [claude.md](claude.md).
This cloud setup is one of several sandboxing options; see
[the comparison](claude.md#sandboxing) there.

[ccweb]: https://code.claude.com/docs/en/claude-code-on-the-web
[ccweb-quickstart]: https://code.claude.com/docs/en/web-quickstart
[claude-code-web]: https://claude.ai/code


## Session workflow

Once you've [set up an environment](#setting-up-an-environment)
(a one-time step, below), what a session needs from you is a
reasonably fresh fork: sessions build on the fork branch you
pick, and your fork's `main` doesn't track upstream's by
itself. A stale branch means stale code and stale Claude
config, so sync when it's been a while: GitHub's
["Sync fork" button][sync-fork], or a Git alias like

```bash
git config alias.sync-fork \
    '!git fetch upstream && git push me upstream/main:main'
```

(adjust to your remote names), making it one command:
`git sync-fork`.

Then pick your fork and branch when starting the session;
[the quickstart][ccweb-quickstart] covers the mechanics.

At the other end, a session hands its work back rather than
landing it. It commits and pushes to its own branch, and may
open a pull request, but only ever a **draft** one, because
the commits are Claude's and a draft says the work still needs
a human (see [Trust model](#trust-model)). Taking it the rest
of the way is local: check out the branch, review and revise,
take authorship of the commits (`--reset-author`), and mark
the PR ready for review once you'd stand behind it.

[sync-fork]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork


## Setting up an environment

At [claude.ai/code][claude-code-web], create an environment for
**your fork** (e.g. `chrisbobbe/zulip-flutter`), not the
upstream repo. The team workflow is fork + PR, and a
SessionStart hook (see below) warns off sessions started on
upstream, where commits would have nowhere good to go.

An environment is configured by filling in text fields in the
web UI:

- **Setup script**: paste this one line:

  ```bash
  /home/user/zulip-flutter/tools/provision-cloud
  ```

  (The path is absolute because, empirically as of 2026-07, the
  script's working directory isn't reliably the checkout.)

  The script installs the needed system packages, sets up the
  Flutter SDK, warms the pub cache, and clones the Zulip server
  repo to `../zulip`. It's short; read it for the details.

  Note there's no automatic sync between the repo and this
  field: the environment cache is invalidated when the field's
  text changes, so edits to `tools/provision-cloud` don't
  invalidate it on their own.

- **Network access**: "Custom", with "Also include default
  list of common package managers" checked, and the allowed
  domains below. The default list covers what the setup script
  needs (apt, GitHub, pub.dev); these otherwise get 403s from
  the egress proxy, whose body names the host and says to add
  it here (2026-07):

  - `chat.zulip.org`, for reading chat threads linked from
    issues and PRs;
  - `zulip.com`, for reading API docs.

  Add these three as well if you want sessions to be able to
  provision a Zulip dev server (see below).  `tools/provision`
  in `../zulip` reaches all three while setting up apt, and
  gives up if any of them 403s:

  - `apt.postgresql.org`, the PGDG repo;
  - `packages.groonga.org`, which serves the package that adds
    the pgroonga repo;
  - `ppa.launchpadcontent.net`, the libheif PPA.

  The last is worth adding either way: the base image ships
  its own PPAs on that host, and their 403s are why
  `tools/provision-cloud` has to tolerate `apt-get update`
  exiting nonzero.

  (Changing the allowed domains invalidates the environment
  cache.)

- **Environment variables**: none needed for ordinary work; a
  GitHub token in particular gains nothing (see "Limitations /
  rough edges" below).

  Two are worth setting if sessions will provision a dev
  server, since the egress gateway presents its own TLS
  certificate and neither tool consults the system trust store
  that already holds the gateway's CA:

  - `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt`,
    or pnpm fails with `SELF_SIGNED_CERT_IN_CHAIN`;
  - `UV_SYSTEM_CERTS=1`, or uv fails with
    `invalid peer certificate: UnknownIssuer`.


## How it works

The setup script runs once, as root, when the environment's
cache is first built; Anthropic then snapshots the filesystem
and starts later sessions from the snapshot. The cache is
invalidated when the setup script or network settings change,
and when it expires after roughly seven days; the next session
start then rebuilds it. Only the setup script's work gets
snapshotted: anything downloaded during a session (pub
packages, Flutter artifacts) is not, which is why the setup
script warms those caches up front.

Each session then starts from a fresh clone of the repo, plus
that snapshot. A SessionStart hook in
[`.claude/settings.json`](../../.claude/settings.json),
[`tools/cloud-session-start`](../../tools/cloud-session-start),
finishes the job in each session:

- if it was started on upstream rather than a fork, tells Claude
  to stop and have you restart on your fork (a SessionStart hook
  can't hard-halt a session, so it warns via context; see above);
- runs `flutter pub get` for the fresh clone (fast, thanks to
  the snapshot's warm pub cache), showing the output on failure
  so Claude can react. For example, since this repo tracks
  Flutter's `main` channel, the cached SDK can fall behind
  `pubspec.yaml`'s minimum Flutter version within the cache's
  lifetime; Claude can then run `flutter upgrade` and retry.

The hook is a no-op outside cloud sessions (it checks
`CLAUDE_CODE_REMOTE`), so local and Lima-VM sessions are
unaffected.


## Limitations / rough edges

- Sessions push without asking: when Claude reaches a stopping
  point, it pushes its branch, and no setting gates that on
  your approval. Anything committed thus becomes public on
  your fork.

- Asking Claude to read issues or PRs on `zulip/zulip-flutter`
  is limited: GitHub API access is scoped to the fork the
  session was started from, and supplying your own token
  doesn't change that. The built-in search tools, `git fetch`
  of PR refs, and WebFetch of github.com pages do reach it;
  issue comments are unreachable by any route, so when a
  comment thread matters, read it locally. Details and the full
  route matrix: [claude-code#78277][cc-78277].

- `flutter test` needs a workaround: the proxy blocks
  `package:sqlite3`'s prebuilt-library download
  ([claude-code#78330][cc-78330]), so
  [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md) has Claude
  switch it to the system SQLite (which the setup script
  installs) before running tests.

  Adding a domain to the environment's allowed list won't fix
  this one. The download comes from a GitHub release, on
  `simolus3/sqlite3.dart`, and what refuses it is the GitHub
  scoping proxy rather than the egress allowlist: it answers
  "GitHub access to this repository is not enabled for this
  session", as it does for any repo but the session's own.

[cc-78277]: https://github.com/anthropics/claude-code/issues/78277
[cc-78330]: https://github.com/anthropics/claude-code/issues/78330


## Running a dev server in a session

A session can run a real Zulip dev server, so Claude can try
API calls against a live server instead of only against
`FakeApiConnection` fixtures.  `../zulip` is already checked
out in the session, and the container is Ubuntu 24.04, a
platform [`tools/provision`][provision-direct] supports.

You won't be able to reach the server yourself: the container
takes no inbound connections, so `localhost:9991` is reachable
only from inside the session.  It's a testbed for Claude, not
a Zulip you can click around in.  It also evaporates with the
session, and a from-scratch provision takes 10–20 minutes, so
it's worth doing only when live-server testing is the point.

Use the [Vagrant-less direct install][provision-direct], since
the session container is already the disposable sandbox that
Vagrant would otherwise provide.  Set up the environment's
allowed domains and environment variables first, as above;
with those in place `tools/provision` runs unmodified, and
only three things differ from a normal direct install:

- **Provision refuses to run as root**, and sessions run as
  root; make a normal user and give it the checkout.
- **There's no systemd.**  Set `GITHUB_ACTIONS=true` so
  provision starts postgres/redis/memcached/rabbitmq with
  plain `service` commands, as Zulip's own CI does.  That's
  the flag's only effect on provision.
- **The container has no IPv6**, so memcached's default
  `-l 127.0.0.1,::1` leaves it dead — while its init script
  still reports it running, from a stale pidfile.  Bind it to
  IPv4 only, or Django 500s on every cache read.

Don't point apt at the egress proxy: it reaches the archives
on its own, and setting `Acquire::http::Proxy` makes the proxy
answer plain-http archive.ubuntu.com with 405s.

Then `tools/run-dev` serves on `localhost:9991`, with realms
at the hostname-derived names in `/api/v1/dev_list_users`
(add them to `/etc/hosts`).  `POST /api/v1/dev_fetch_api_key`
gets credentials for any dev user without a password.

To exercise our own bindings rather than curl, see
[`test/api/live_server_probe.dart`](../../test/api/live_server_probe.dart).
Note it builds `ApiConnection` directly rather than with
`ApiConnection.live`, to skip the `ZulipBinding` dependency;
once [#2335][] makes `lib/api` usable from plain Dart, a
standalone script could drive the bindings without
`flutter test` at all.

[provision-direct]: https://zulip.readthedocs.io/en/latest/development/setup-advanced.html#installing-directly-on-ubuntu-debian-centos-or-fedora
[#2335]: https://github.com/zulip/zulip-flutter/issues/2335


## Trust model

Unlike the [Lima setup](lima.md#trust-model), where pushing is
reserved for the host, cloud sessions are designed to push:
Anthropic's GitHub proxy holds your real credentials outside
the sandbox, and hands the session a scoped credential that can
push only to the session's own working branch. Review anything
it produces like any other contributor's work, per Zulip's
[AI use policy][ai-policy].

Commits made in a session are authored, committed, and
SSH-signed as Anthropic's `claude` GitHub identity (GitHub
shows them "Verified"), with your name nowhere on them. As
provenance for a draft on your fork, that's honest; but a
commit with no responsible human author shouldn't land in a
PR. When adopting a session's commit, take authorship
(`git cherry-pick` preserves the old author; amend with
`--reset-author`), and let a Co-Authored-By trailer credit
Claude, as with local Claude commits. The `authorship` suite
in `tools/check` enforces this, in CI and locally. A PR the
session opens is the reverse: it's created on behalf of your
own GitHub account. So a session opens one only as a draft,
a handoff that still needs you to adopt the commits and mark
it ready for review.

[ai-policy]: https://zulip.readthedocs.io/en/latest/contributing/contributing.html#ai-use-policy-and-guidelines


## Questions or trouble?

Ask in [`#mobile-dev-help`][mobile-dev-help] on chat.zulip.org.

[mobile-dev-help]: https://chat.zulip.org/#narrow/channel/516-mobile-dev-help

# Developing with Claude Code on the web

[Claude Code on the web][ccweb] runs each Claude session in an
Anthropic-hosted VM, cloned fresh from the repo. It's useful for
delegating tasks without tying up a local machine. Sessions can
be started and steered from [claude.ai/code][claude-code-web]
in a browser, or from the Claude mobile app's Code tab (see the
[quickstart][ccweb-quickstart]). To use it for this repo, do
the [one-time setup](#one-time-setup), then follow the
[session workflow](#session-workflow). Read the
[limitations](#limitations--rough-edges) too, before relying
on it.

The tips in [claude.md](claude.md) apply in cloud sessions too;
that doc also [compares](claude.md#sandboxing) this with the
local sandboxing options.

[ccweb]: https://code.claude.com/docs/en/claude-code-on-the-web
[ccweb-quickstart]: https://code.claude.com/docs/en/web-quickstart
[ccweb-connect]: https://code.claude.com/docs/en/web-quickstart#connect-github
[ccweb-troubleshoot]: https://code.claude.com/docs/en/web-quickstart#troubleshoot-setup
[ccweb-start]: https://code.claude.com/docs/en/web-quickstart#start-a-task
[claude-code-web]: https://claude.ai/code


## One-time setup

You'll need a Claude plan that includes Claude Code on the web
(Pro, Max, or Team), and a fork of zulip-flutter on GitHub. If
you don't have a fork: signed in to GitHub, press "Fork" near
the top of [zulip/zulip-flutter][upstream-repo] and accept the
defaults ([GitHub's guide][fork-a-repo] has more). You'll run
web sessions on your fork, not on zulip/zulip-flutter.

1. **Connect GitHub.** At [claude.ai/code][claude-code-web],
   sign in (choosing "Continue on web" if offered the desktop
   app instead), then follow the prompt to sign in with GitHub
   and approve the authorization. If asked to install the
   Claude GitHub App, you can skip it; it enables only the
   "Auto-fix" feature, which isn't needed. If onboarding then
   shows a "Create your first cloud environment" form, keep its
   defaults and finish; the next step covers what that was
   about, and adds a second one set up for this repo.

   > [!TIP]
   > If the GitHub sign-in shows "GitHub access is required"
   > and no button, an Owner of your Claude organization must
   > first turn on the GitHub connector (Admin settings >
   > Connectors); ask them, then reload the page and start over.
   >
   > If it otherwise doesn't go as described, the quickstart's
   > [Connect GitHub][ccweb-connect] steps and its
   > [troubleshooting][ccweb-troubleshoot] section cover the
   > variations (no repositories listed, only a login button,
   > and so on).

2. **Create an environment** for this repo. An environment is
   a saved configuration for sessions: network access,
   environment variables, and a setup script that runs when a
   new session starts. On [claude.ai/code][claude-code-web],
   open the environment selector, the cloud icon in the row
   above the message box (it shows the current environment's
   name, "Default" so far), and choose "Add cloud environment".
   In the dialog:

   - **Name**: something you'll recognize in that selector,
     such as `zulip-flutter`.

     The script runs once per build of the environment's cache,
     which takes about three minutes (observed 2026-09): at your
     first session in the environment, and again whenever the
     cache expires, roughly weekly. Sessions in between start in
     seconds.

   - **Network access**: "Custom", with "Also include default
     list of common package managers" checked, and two allowed
     domains:

     - `chat.zulip.org`, for reading chat threads linked from
       issues and PRs;
     - `zulip.com`, for reading API docs.

     (Without the default list, the setup script fails with 403s
     from apt, the Ubuntu archives included.)

     Add these three as well if you want sessions to be able to
     provision a Zulip dev server (see
     [Running a dev server](#running-a-dev-server-in-a-session)).
     `tools/provision` in `../zulip` reaches all three while
     setting up apt, and gives up if any of them 403s:

     - `apt.postgresql.org`, the PGDG repo;
     - `packages.groonga.org`, which serves the package that
       adds the pgroonga repo;
     - `ppa.launchpadcontent.net`, the libheif PPA.

     The last is worth adding either way: the base image ships
     its own PPAs on that host, and their 403s are why
     `tools/provision-cloud` has to tolerate `apt-get update`
     exiting nonzero.

   - **Environment variables**: none needed for ordinary work.
     Set `ZULIP_DEV_SERVER=1` to have the setup script provision
     a Zulip dev server (see
     [Running a dev server](#running-a-dev-server-in-a-session)),
     along with the three allowed domains above.

   - **Setup script**: paste this one line:

     ```bash
     /home/user/zulip-flutter/tools/provision-cloud
     ```

     (If your fork isn't named `zulip-flutter`, adjust the path
     to match.) The script installs the system packages and the
     Flutter SDK, warms the pub cache, and clones the Zulip
     server repo to `../zulip` and the legacy mobile app's to
     `../zulip-mobile`.

[upstream-repo]: https://github.com/zulip/zulip-flutter
[fork-a-repo]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo


## Session workflow

1. **Sync your fork** when it's been a while. Sessions build
   on the fork branch you pick, and your fork's `main` doesn't
   track upstream's by itself. A stale branch means stale code
   (so stale answers) and stale Claude config. GitHub's
   ["Sync fork" button][sync-fork] does it, or a Git alias like

   ```bash
   git config alias.sync-fork \
       '!git fetch upstream && git push me upstream/main:main'
   ```

   (adjust to your remote names), making it one command:
   `git sync-fork`.

2. **Start the session** at [claude.ai/code][claude-code-web]
   or in the mobile app's Code tab: pick your fork and branch,
   the environment you created in [One-time setup](#one-time-setup)
   (via the same cloud icon), and a permission mode, and
   describe the task (the quickstart's
   [Start a task][ccweb-start] walks through the controls).
   The session clones that branch, runs the
   SessionStart hook (see [How it works](#how-it-works)), works
   on the branch, and pushes to it when it reaches a stopping
   point. The first session in a new environment takes a few
   minutes to start while the setup script runs (see
   [One-time setup](#one-time-setup)); later sessions start from
   the cached result in seconds, until the cache expires and the
   next start rebuilds it.

3. **Follow along.** A session is a chat like any other: read
   Claude's replies, answer its questions, and send follow-ups
   to steer it, or step away and come back when it's done. If
   it changes code, the diff view shows the changes so far;
   you can comment on specific lines there, and the comments
   queue up and go to Claude along with your next chat message.

If you only wanted answers, you're done. The rest applies when
the session wrote commits you want to send in a PR.

4. **Receive the handoff.** A session's work comes back to you
   to finish, not straight to review. It may open a pull
   request, but only ever a **draft** one: the commits are
   Claude's, and a draft says the work still needs a human (see
   [Trust model](#trust-model)). Taking it the rest of the way
   is local, in the steps below.

5. **Test it yourself**, when the change calls for it. The
   cloud VM has no device or emulator, so this has to be done
   on your machine. [Teleport][teleport] the session there:
   `claude --teleport` offers a picker of your sessions (or
   copy the exact command from the session's menu on the web,
   "Open in > Terminal"). That checks out the session's branch
   and brings the conversation along. Then run the app as
   usual; see the [README](../../README.md).

6. **Take authorship** of the commits, in that same checkout.
   Neither teleporting nor `git cherry-pick` changes an author,
   so amend each commit that's Claude's with `--reset-author`.

7. **Send the PR.** If the session opened a draft PR, mark it
   ready for review on GitHub once you'd stand behind it (per
   Zulip's [AI use policy][ai-policy]). If it didn't, open one
   yourself.

[sync-fork]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork
[teleport]: https://code.claude.com/docs/en/claude-code-on-the-web#from-web-to-terminal


## Limitations / rough edges

- Sessions push without asking: when Claude reaches a stopping
  point, it pushes its branch, and no setting gates that on your
  approval (checked 2026-09). Anything committed thus becomes
  public on your fork.

- The VM has no device or emulator, so the app can't be run
  there. Manual testing means teleporting the branch to your
  machine; see the [session workflow](#session-workflow).

- The VM's network is allowlisted: commands Claude runs there
  reach the default package registries, GitHub, and the domains
  added in setup, and nothing else. (Claude's WebFetch tool is
  unaffected, since that tool fetches from outside the VM;
  checked 2026-07.) If a task needs another site, add its
  domain to the environment, and consider adding it to the
  setup instructions above.

- Claude can't read everything on `zulip/zulip-flutter` from a
  session: GitHub API access is scoped to your fork (a GitHub
  token of your own doesn't change that), so upstream issues
  and PRs reach it only by some routes, and issue comments by
  none (checked 2026-07). When a comment thread matters, paste
  it into the session. Details: [claude-code#78277][cc-78277].

- `flutter test` needs a workaround, which Claude applies on its
  own: one package's download of a prebuilt library is refused
  ([claude-code#78330][cc-78330]), so CLAUDE.md has Claude use
  the system library instead, via a pubspec.yaml edit it keeps
  out of commits.

  Adding a domain to the environment won't fix this one. The
  download comes from a GitHub release, on
  `simolus3/sqlite3.dart`, and what refuses it is the GitHub
  scoping proxy rather than the egress allowlist: it answers
  "GitHub access to this repository is not enabled for this
  session", as it does for any repo but the session's own.

[cc-78277]: https://github.com/anthropics/claude-code/issues/78277
[cc-78330]: https://github.com/anthropics/claude-code/issues/78330


## Trust model

Unlike the [Lima setup](lima.md#trust-model), where pushing is
reserved for the host, cloud sessions are designed to push:
Anthropic's GitHub proxy holds your real credentials outside
the sandbox, and hands the session a credential scoped to your
fork (pushing a new branch there worked, 2026-09). Since
sessions push, they run on a fork even for those with push
access upstream: scratch branches don't belong there. Review
anything it produces like any other contributor's work, and
test it yourself where the change calls for it, since the
session can't run the app. See Zulip's
[AI use policy][ai-policy].

Commits made in a session are created with Claude as the
author and committer (`noreply@anthropic.com`), not your name,
and you're expected to take authorship at the moment you're
ready to stand behind the commits, before sending a non-draft
PR (see [session workflow](#session-workflow)), which leaves
Claude credited in a Co-Authored-By trailer. The `authorship`
suite in `tools/check` enforces this in CI.
(Locally, run it by name: `tools/check authorship`.)

(Commits are also unsigned: the container would sign them as
Anthropic's `claude` GitHub identity, but the session-start
hook turns that off, since the signature would stop meaning
anything once you take authorship.)

[ai-policy]: https://zulip.readthedocs.io/en/latest/contributing/contributing.html#ai-use-policy-and-guidelines


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

Two notes on maintaining your environment:

- The setup-script field invokes the script by absolute path,
  so the script can find the checkout from its own location;
  the working directory it's started in isn't reliably the
  checkout (observed 2026-07).
- The cache is keyed on the field's text (and the network
  settings), not on the script's contents. So when
  `tools/provision-cloud` changes in the repo, your environment
  keeps the old script's results until the cache expires or you
  force a rebuild by changing the field, e.g. by adding or
  bumping a `# v2` comment after the command.

Each session then starts from a fresh clone of the repo, plus
that snapshot, and runs a SessionStart hook,
[`tools/cloud-session-start`](../../tools/cloud-session-start)
(configured in [`.claude/settings.json`](../../.claude/settings.json)).
The hook:

- if it was started on upstream rather than a fork, tells Claude
  to stop and have you restart on your fork (a SessionStart hook
  can't hard-halt a session, so it warns via context);
- turns off commit signing, which would otherwise sign as
  Anthropic's `claude` identity (see [Trust model](#trust-model));
- fetches your fork's `main` and unshallows the clone, which
  starts out shallow and single-branch, so that `tools/check`
  can find the branch's merge-base;
- runs `flutter pub get` for the fresh clone (fast, thanks to
  the snapshot's warm pub cache), showing the output on failure
  so Claude can react, say with `flutter upgrade` when the
  cached SDK has fallen behind `pubspec.yaml`.

The hook is a no-op outside cloud sessions (it checks
`CLAUDE_CODE_REMOTE`), so local and Lima-VM sessions are
unaffected.


## Running a dev server in a session

A session can run a real Zulip dev server, so Claude can try
API calls against a live server instead of only against
`FakeApiConnection` fixtures. `../zulip` is already checked
out in the session, and the VM is Ubuntu 24.04, a platform
[`tools/provision`][provision-direct] supports.

You won't be able to reach the server yourself: the VM takes
no inbound connections, so `localhost:9991` is reachable only
from inside the session. It's a testbed for Claude, not a
Zulip you can click around in.

To enable it, set `ZULIP_DEV_SERVER=1` in the environment's
"Environment variables" field, along with the three allowed
domains above. `tools/provision-cloud` then provisions the
server checkout, and `tools/cloud-dev-server` starts it in a
session:

```bash
tools/cloud-dev-server status   # is one available, and serving?
tools/cloud-dev-server          # start it
tools/cloud-dev-server stop
```

Provisioning happens at cache-build time deliberately. It
takes 10-20 minutes, and only the setup script's work reaches
the environment cache, so a session that provisioned its own
would pay that cost every time. Starting an already-provisioned
one takes about 15 seconds, or a couple of minutes the first
time after provisioning, when it still has assets to compile.
The tradeoff is that every rebuild of the cache pays the
provisioning cost, which is why it's opt-in. If provisioning
fails, the build carries on without a dev server rather than
leaving you with no environment at all.

`POST /api/v1/dev_fetch_api_key` then gets credentials for any
dev user without a password, and
[`test/api/live_server_probe.dart`](../../test/api/live_server_probe.dart)
drives our own bindings against the server rather than curl.
Note it builds `ApiConnection` directly rather than with
`ApiConnection.live`, to skip the `ZulipBinding` dependency;
once [#2335][] makes `lib/api` usable from plain Dart, a
standalone script could drive the bindings without
`flutter test` at all.

### What the scripts work around

Recorded here because the scripts' comments are terse, and
because anyone provisioning a server by hand will meet these.
The VM is Ubuntu 24.04, a platform
[`tools/provision`][provision-direct] supports directly; use
that Vagrant-less path, since the session VM is already the
disposable sandbox Vagrant would otherwise provide. With the
allowed domains set, provision runs unmodified, and only
three things differ from a normal direct install:

- **Provision refuses to run as root**, and sessions run as
  root; hence the `zulipdev` user that owns the checkout.
- **There's no systemd**, hence `GITHUB_ACTIONS=true`, which
  makes provision start postgres/redis/memcached/rabbitmq with
  plain `service` commands, as Zulip's own CI does. That's
  the flag's only effect on provision.
- **The VM has no IPv6**, so memcached's default
  `-l 127.0.0.1,::1` leaves it dead, while its init script
  still reports it running, from a stale pidfile. Django then
  500s on every cache read.

Two more, about running the server rather than provisioning it:

- **Set `EXTERNAL_HOST=localhost:9991`.** Left unset,
  `dev_settings.py` puts the realms on subdomains of the VM's
  hostname, which resolve nowhere; setting it serves the main
  realm at plain `localhost` and turns off the dev CAPTCHA.
  Beware that naming the server user `zulipdev` is itself
  load-bearing here: that name is how the server detects a dev
  droplet, which changes the default.
- **Don't point apt at the egress proxy.** It reaches the
  archives on its own, and setting `Acquire::http::Proxy`
  makes the proxy answer plain-http archive.ubuntu.com with
  405s.

[provision-direct]: https://zulip.readthedocs.io/en/latest/development/setup-advanced.html#installing-directly-on-ubuntu-debian-centos-or-fedora
[#2335]: https://github.com/zulip/zulip-flutter/issues/2335


## Questions or trouble?

Ask in [`#mobile-dev-help`][mobile-dev-help] on
[chat.zulip.org][czo].

[czo]: https://zulip.com/development-community/
[mobile-dev-help]: https://chat.zulip.org/#narrow/channel/516-mobile-dev-help

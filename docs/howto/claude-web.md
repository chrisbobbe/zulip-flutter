# Developing with Claude Code on the web

[Claude Code on the web][ccweb] runs each Claude session in an
Anthropic-hosted VM, cloned fresh from the repo. It's useful for
delegating tasks without tying up a local machine. Sessions can
be started and steered from [claude.ai/code][claude-code-web]
in a browser, or from the Claude mobile app's Code tab (see the
[quickstart][ccweb-quickstart]). This doc covers using it for
this repo. To use it, do the [one-time setup](#one-time-setup),
then follow the [session workflow](#session-workflow); the rest
of the doc explains how it works and why, for the curious.

For local development with Claude, see [claude.md](claude.md).
This cloud setup is one of several sandboxing options; see
[the comparison](claude.md#sandboxing) there.

[ccweb]: https://code.claude.com/docs/en/claude-code-on-the-web
[ccweb-quickstart]: https://code.claude.com/docs/en/web-quickstart
[ccweb-connect]: https://code.claude.com/docs/en/web-quickstart#connect-github
[ccweb-troubleshoot]: https://code.claude.com/docs/en/web-quickstart#troubleshoot-setup
[ccweb-start]: https://code.claude.com/docs/en/web-quickstart#start-a-task
[claude-code-web]: https://claude.ai/code


## One-time setup

**Questions only?** If you want answers from the code rather
than changes to it (say, how the mobile app handles some
feature), you need steps 1 to 3 below, and can skip step 4:
pick the shared `zulip-flutter` environment if there is one
(see step 4), or else the **Default** environment that
onboarding creates, which is enough for reading code. (Without
the setup script it has no Flutter SDK, so the session can't
run the analyzer or tests, and the SessionStart hook's
`flutter pub get` should fail visibly but harmlessly.) Then
follow the [session workflow](#session-workflow) through
step 3.

1. **Check your access.** Claude Code on the web comes with
   the Pro, Max, and Team plans. On a Team plan, like ours, an
   Owner of the Claude organization must first turn on the
   GitHub connector (Admin settings > Connectors); until then,
   the GitHub sign-in in step 3 shows "GitHub access is
   required" and no button. If that's what you see, ask your
   organization's Claude admin.

2. **Have a fork** of zulip-flutter on GitHub, as for any
   contribution. Sessions always run on your fork, never on
   `zulip/zulip-flutter` itself, even for questions: a session
   pushes what it commits, and scratch branches don't belong
   on upstream. (In practice the fork is also what makes
   zulip-flutter appear in the repository picker at all: a
   public repo we had no access to was rejected when tried,
   2026-09, though Anthropic's docs describe access more
   broadly.)

3. **Connect GitHub.** At [claude.ai/code][claude-code-web],
   sign in (choosing "Continue on web" if offered the desktop
   app instead), then follow the prompt to sign in with GitHub
   and approve the authorization. If asked to install the
   Claude GitHub App, skip it: it enables only the "Auto-fix"
   feature, and sessions reach your fork without it. (If you
   use the `gh` CLI, `/web-setup` in a local Claude Code
   session does the same from the terminal, where your
   organization allows it.) If it doesn't go as described, the
   quickstart's [Connect GitHub][ccweb-connect] steps and its
   [troubleshooting][ccweb-troubleshoot] section cover the
   variations (no repositories listed, only a login button,
   and so on); the rest of that page isn't needed.

4. **Create an environment**, or use the shared one. On our
   Team plan, an Owner of the Claude organization can publish
   an environment shared with every member; if one named
   `zulip-flutter` appears in your environment selector, pick
   it and skip the rest of this step. (Create a personal one
   only if you want the `ADOPT_AUTHOR_*` variables below, which
   are per-person.) Otherwise create your own, named
   `zulip-flutter` too, so the link in the session workflow
   finds it. (A SessionStart hook, see below, warns off
   sessions started on upstream by mistake.) An environment is
   configured by filling in text fields in the web UI:

   - **Setup script**: paste this one line:

     ```bash
     /home/user/zulip-flutter/tools/provision-cloud
     ```

     (If your fork isn't named `zulip-flutter`, adjust the path
     to match.) The script installs the system packages and the
     Flutter SDK, warms the pub cache, and clones the Zulip
     server repo to `../zulip`. No need to read it; it's there
     if you're curious.

   - **Network access**: "Custom", with "Also include default
     list of common package managers" checked, and two allowed
     domains. The default list covers what the setup script needs
     (apt, GitHub, pub.dev); the two domains below otherwise get
     403s from the egress proxy (2026-07):

     - `chat.zulip.org`, for reading chat threads linked from
       issues and PRs;
     - `zulip.com`, for reading API docs.

   - **Environment variables**: optionally `ADOPT_AUTHOR_NAME`
     and `ADOPT_AUTHOR_EMAIL`, your name and email, for taking
     authorship of commits from inside a session (see "Session
     workflow" below). Nothing else is needed; a GitHub token in
     particular gained nothing when tried, 2026-07 (see
     "Limitations / rough edges" below).


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
   (this [link][ccweb-prefilled] preselects the `zulip-flutter`
   environment) or in the mobile app's Code tab: pick your fork
   and branch, a permission mode, and describe the task (the
   quickstart's [Start a task][ccweb-start] walks through the
   controls). The session clones that branch, runs the
   SessionStart hook (see [How it works](#how-it-works)), works
   on the branch, and pushes to it when it reaches a stopping
   point.

3. **Review as it goes.** The session's diff view shows its
   changes so far; inline comments there reach Claude with
   your next message.

If you only wanted answers, you're done. The rest applies when
the session wrote code you want to land.

4. **Receive the handoff.** A session hands its work back
   rather than landing it. It may open a pull request, but as
   a **draft** while the commits are Claude's: a draft says the
   work still needs a human (see [Trust model](#trust-model)).
   Taking it the rest of the way is yours, in the next two
   steps.

5. **Take authorship** of the commits, with one command,
   `tools/check --fix authorship`, which re-authors the ones
   that are Claude's. Either:

   - from a terminal: [teleport][teleport] the session with
     `claude --teleport <session-id>`, which checks out its
     branch and brings the conversation along, and run the
     command there; or
   - from inside the session, with no terminal, by telling
     the session to. For that to re-author the commits as you
     rather than as Claude, first put your name and email in
     the environment's variables as `ADOPT_AUTHOR_NAME` and
     `ADOPT_AUTHOR_EMAIL` (see [One-time setup](#one-time-setup)).
     Only that command reads them, so the session's other
     commits stay Claude's.

6. **Mark the PR ready** for review once you'd stand behind
   it. (Having taken authorship from inside the session, you
   can instead have the session open the PR as ready in the
   first place.)

[ccweb-prefilled]: https://claude.ai/code?environment=zulip-flutter
[sync-fork]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork
[teleport]: https://code.claude.com/docs/en/claude-code-on-the-web#from-web-to-terminal


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

Two notes for whoever maintains the environment configuration.
The setup-script field invokes the script by absolute path
because, empirically as of 2026-07, the script's working
directory isn't reliably the checkout. And there's no
automatic sync between the repo and the field: the cache is
keyed on the field's text (and the network settings), so edits
to `tools/provision-cloud` don't invalidate it on their own.
To force a rebuild after such an edit, change the field, e.g.
by adding or bumping a `# v2` comment after the command.

Each session then starts from a fresh clone of the repo, plus
that snapshot. A SessionStart hook in
[`.claude/settings.json`](../../.claude/settings.json),
[`tools/cloud-session-start`](../../tools/cloud-session-start),
finishes the job in each session:

- if it was started on upstream rather than a fork, tells Claude
  to stop and have you restart on your fork (a SessionStart hook
  can't hard-halt a session, so it warns via context; see above);
- turns off commit signing, which would otherwise sign as
  Anthropic's `claude` identity (see [Trust model](#trust-model));
- fetches your fork's `main`, which the session's shallow,
  single-branch clone lacks and `tools/check` needs, to find
  the branch's merge-base;
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
  doesn't change that. As of 2026-07, the built-in search
  tools, `git fetch` of PR refs, and WebFetch of github.com
  pages did reach it, and issue comments were unreachable by
  any route, so when a comment thread matters, read it locally.
  Details and the full route matrix: [claude-code#78277][cc-78277].

- `flutter test` needs a workaround: the proxy blocks
  `package:sqlite3`'s prebuilt-library download, a GitHub
  release asset of a repo other than the session's, which the
  proxy's [documented repository scope][ccenv-scope] excludes
  ([claude-code#78330][cc-78330]); so
  [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md) has Claude
  switch it to the system SQLite (which the setup script
  installs) before running tests.

[cc-78277]: https://github.com/anthropics/claude-code/issues/78277
[cc-78330]: https://github.com/anthropics/claude-code/issues/78330
[ccenv-scope]: https://code.claude.com/docs/en/cloud-environments#github-proxy


## Trust model

Unlike the [Lima setup](lima.md#trust-model), where pushing is
reserved for the host, cloud sessions are designed to push:
Anthropic's GitHub proxy holds your real credentials outside
the sandbox, and hands the session a credential scoped to your
fork (pushing a new branch there worked, 2026-09). Review anything
it produces like any other contributor's work, per Zulip's
[AI use policy][ai-policy].

Commits made in a session are authored and committed as
Claude (`noreply@anthropic.com`), with your name nowhere on
them, and unsigned: the container would sign them as
Anthropic's `claude` GitHub identity, but the session-start
hook turns that off, since the signature would stop meaning
anything once you take authorship. As provenance for a draft
on your fork, that's honest; but a commit with no responsible
human author shouldn't land in a PR. When adopting a session's
commits, take authorship: `tools/check --fix authorship`
re-authors the ones that are Claude's (`--teleport` and
`git cherry-pick` both preserve the old author), leaving
Claude credited in a Co-Authored-By trailer, as with local
Claude commits (it adds the trailer if the session didn't).
The `authorship` suite in `tools/check` enforces this in CI
(locally, run it by name; in a cloud session, where the fork's
`main` stands in for upstream's, a stale fork widens the range
it examines, harmlessly). Run the fix yourself, at the moment
you're ready to stand behind the commits; a session doesn't
run it on its own initiative (Claude's instructions say so).
A PR the session opens is the reverse: it's created on behalf
of your own GitHub account. So while any commit is Claude's,
a session opens one only as a draft: a handoff that still
needs you to adopt the commits and mark it ready for review.
Once you have, and the `authorship` suite passes, the session
may open it as ready at your request. (Converting an existing
draft to ready is yours to do, on GitHub.)

[ai-policy]: https://zulip.readthedocs.io/en/latest/contributing/contributing.html#ai-use-policy-and-guidelines


## Questions or trouble?

Ask in [`#mobile-dev-help`][mobile-dev-help] on
[chat.zulip.org][czo].

[czo]: https://zulip.com/development-community/
[mobile-dev-help]: https://chat.zulip.org/#narrow/channel/516-mobile-dev-help

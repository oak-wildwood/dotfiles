# Agent instructions

Instructions for AI coding agents working in this repository. Humans should read the
[README](./README.md).

## What this is

One person's macOS dotfiles: git config, zsh config, and Claude Code preferences, symlinked into
place by `./bootstrap`.

It is deliberately small, and keeping it small is a feature rather than an oversight. The value is
that a new machine gets a working setup in one command, not that every preference is captured.
Resist adding frameworks, plugin managers, or per-machine templating — the moment this needs
explaining, it has failed at its job.

## Hard rules

**Never commit a secret, a token, or a real email address.** This repo is public and its entire
purpose involves the file that sets commit identity. Anything machine-specific or sensitive belongs
in `~/.zshrc.local`, which is sourced by `.zshrc` and is not tracked.

**Never vendor someone else's skill, plugin, or tool.** `claude/INSTALLED.md` records what is
installed. A copy would go stale the moment upstream changed and would drag their licensing in with
it. Record, don't copy.

**Never make `bootstrap` destructive.** It moves existing files aside with a timestamped suffix and
never deletes. Someone running this on a machine they have already configured must not lose
anything, because they usually do not know what was there.

## Things worth knowing

`.zshrc` guards the `starship` call with `command -v`. A new machine has the dotfiles before it has
the tools, and an unguarded eval means every shell opens with an error until the tool is installed.
Any tool added to the shell config should be guarded the same way.

`bootstrap` is idempotent and has a `--dry-run`. Test with it before testing without it — this
script writes to `$HOME`.

macOS only, on purpose. Do not add Linux or WSL branches; there is no one to test them and dead
branches rot.

## PR titles become commit messages

This repo squash-merges, and the squashed commit takes the PR title as its subject with an empty
body. Write it as a conventional commit: `type: imperative summary`, lowercase after the colon, no
trailing period.

```
feat: add a ripgrep alias
fix: guard the starship eval on a fresh machine
docs: explain why skills are recorded rather than vendored
```

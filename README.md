# dotfiles

My preferred settings when setting up a new dev machine. macOS only — that's the only kind of
machine I use, so there's no cross-platform branching to reason about.

Deliberately small. This holds the handful of things that are genuinely mine and would otherwise
have to be rebuilt from memory: git aliases, shell aliases, and a commit identity that doesn't
publish my email address.

## Setup on a new Mac

```bash
git clone git@github.com:oak-wildwood/dotfiles.git ~/Code/dotfiles
cd ~/Code/dotfiles
./bootstrap --dry-run   # see what it would do
./bootstrap
```

Then open a new shell.

Prerequisites, in order — Homebrew first, since `.zprofile` calls it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install starship gh jq
```

`bootstrap` tells you which of these are missing rather than failing, and `.zshrc` guards the
starship call, so a shell opened before you've installed it still works.

## What's in it

| Path | Links to | Why |
| --- | --- | --- |
| `git/gitconfig` | `~/.gitconfig` | Aliases, and the noreply commit email |
| `git/ignore` | `~/.config/git/ignore` | Global ignores |
| `zsh/zshrc` | `~/.zshrc` | Aliases, history, prompt |
| `zsh/zprofile` | `~/.zprofile` | Homebrew shell environment |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code preferences |
| `claude/statusline.sh` | `~/.claude/statusline-command.sh` | Claude Code status line: model, dir, git, context and rate-limit bars |
| `claude/INSTALLED.md` | — | A record of installed skills and plugins |

### The aliases

```
git co    checkout          gs   git status
git cob   checkout -b       gd   git diff
git p     pull              gl   git log --oneline -20
git gp    pull              gco  git checkout
git latest pull origin main gcb  git checkout -b
                            ll   ls -la
```

## Why symlinks

`bootstrap` symlinks rather than copies, so editing a file here takes effect immediately and
`git status` shows anything that has drifted. A copy-based setup gives you two versions that
silently disagree, and you find out months later which one you'd actually been editing.

It's safe to re-run. An existing symlink is left alone; a real file is moved to
`<name>.backup-<timestamp>` before being replaced, never deleted. On a new machine you often don't
know what was already there, so nothing is thrown away.

## The commit email thing

The single most useful line in here is the email in `git/gitconfig`.

A real address in git author metadata is public forever in a public repo, and it's easy to miss:
GitHub's web UI commits under your noreply address while command-line pushes use whatever
`~/.gitconfig` says. The two can disagree for months.

GitHub's *Settings → Emails → Block command line pushes that expose my email* catches the common
case, but only for addresses already registered to your account and marked private. An address it
has never seen — a work address, a typo — goes straight through. So the belt-and-braces is having
the right value in `~/.gitconfig` on every machine, which is what this repo is for. `bootstrap`
checks it and says so either way.

## Machine-specific things

Anything that shouldn't be public — work remotes, tokens, one-off paths — goes in
`~/.zshrc.local`, which `.zshrc` sources last if it exists and which is not tracked here.

## What's deliberately not here

**Installed skills and plugins.** `claude/INSTALLED.md` records what's installed rather than
vendoring copies. They're other people's tools, some Apache-licensed; a copy here would go stale
the moment they update and would carry their licensing along with it.

**SSH config.** Hostnames and usernames in a public repo are a standing disclosure for no real
convenience.

## Related

[`gh-repo-init`](https://github.com/oak-wildwood/gh-repo-init) is the per-repository counterpart —
merge settings, commit message format, and agent instruction files. This repo is machine state;
that one is repository state.

## License

MIT — see [LICENSE](./LICENSE).

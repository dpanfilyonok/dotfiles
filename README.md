# dotfiles

Machine settings for the agent stack: the global [skillshare](https://github.com/runkids/skillshare) layer and what skillshare does not cover. Settings outside the agent stack are not kept here.

Projects declare their own skills in their own `.skillshare/`. This repository holds only the global layer, the skills every project on the machine gets.

## Manager: chezmoi

Files are managed by [chezmoi](https://www.chezmoi.io/). It was chosen for three things this repository needs:

- **Path templates.** skillshare keeps its global config in `%APPDATA%\skillshare` on Windows and in `~/.config/skillshare` elsewhere, and the config holds absolute paths. chezmoi renders both from one template and puts it where the OS expects.
- **Restore from GitHub in one command.** `chezmoi init --apply` clones and applies.
- **Scripts on change.** A `run_onchange_` script reinstalls skills when the skill list changes, and only then.

Considered and rejected: GNU Stow and bare-repo setups have no templates, so absolute paths would be committed; yadm does not run natively on Windows; a hand-written bootstrap script would reimplement templating.

## Prerequisites

`git` (on Windows: Git for Windows, whose bash runs the scripts), `chezmoi`, `skillshare`, `jq`, `gitleaks`, `lefthook`. `orca` only if you use Orca.

## Restore on a clean profile

```sh
chezmoi init --apply dpanfilyonok/dotfiles
```

This writes the skillshare config, installs every skill from [`home/.chezmoidata/skills.yaml`](home/.chezmoidata/skills.yaml) at its pin, syncs the targets and runs the version check. Check the result:

```sh
skillshare list -g
skillshare diff -g
```

Then, to work on this repository:

```sh
chezmoi cd
lefthook install
```

## Layout

| Path | What it is |
|---|---|
| `home/` | chezmoi source state (`.chezmoiroot`); everything else in the repository is not applied to the home directory |
| `home/.chezmoidata/skills.yaml` | The global skill list, each skill pinned to a tag or commit |
| `home/.chezmoitemplates/skillshare-config.yaml` | skillshare config: sources, targets, audit threshold |
| `home/.chezmoiscripts/` | Install and sync after apply, then the version check |
| `bin/check-skill-versions.sh` | Version check of skills shared with local projects |

## Skills

skillshare is the only skill manager on the machine. The skill list lives in `skills.yaml`, not in `config.yaml`: skillshare keeps installed skills in `skills/.metadata.json` and drops a `skills:` list from the global config after installing it.

To add or move a pin, edit `skills.yaml` and run `chezmoi apply`. Removing an entry does not uninstall the skill; the install script names it as undeclared, and `skillshare uninstall -g <name>` removes it.

| Skill | Why it is global | Pin |
|---|---|---|
| `find-skills` | Searching for new skills is the owner's call, not agent work inside a project | Same commit as projects that also declare it |
| `skillshare` | Skill of a tool installed on the machine | `skillshare version` |
| `my-*` | Personal bundle from [agent-kit](https://github.com/dpanfilyonok/agent-kit) | agent-kit tag |
| `orca-cli`, `orca-linear`, `orchestration` | Orca is installed on this machine only | `orca --version` |

A skill of a tool follows the tool: when the tool is upgraded, its pin in `skills.yaml` moves to the new version in the same change.

Do not install skills around skillshare:

- `orca skills install` and `orca skills update` are not used. They install through the community skills CLI (`npx skills`), a second manager with its own lockfile `~/.agents/.skill-lock.json`.
- `npx skills add` is not used for the same reason.
- `aspire agent init` is not run against the global skill directories. Aspire skills belong to projects with an Aspire stack, which declare them in their own `.skillshare/`.

### Local only

`skillshare diff -g` shows one directory that skillshare does not manage, and that is expected:

| Target | Directory | Owner |
|---|---|---|
| `claude` | `synced` | Claude app: skills synced from claude.ai. Do not collect it into skillshare. |

Anything else reported as local only has no owner: find out where it came from, then declare it in `skills.yaml` or remove it.

## Version check

A skill declared both here and in a project must sit at one version in both layers. A project's CI does not see the global layer, so the check lives here.

List local project roots, one per line, in `~/.config/dotfiles/projects` (or `$XDG_CONFIG_HOME/dotfiles/projects`). The file stays outside Git: it holds paths of one machine. `#` starts a comment.

```sh
sh bin/check-skill-versions.sh
```

It compares same-named skills of the global registry with each project's `.skillshare/skills.lock.json` by tree hash and names every mismatch with both versions. Exit 0 means all match, 1 a mismatch or a listed project without a lockfile, 2 the check could not run. `chezmoi apply` runs it after every apply and reports a mismatch without failing: the project owns its pin, and apply should not wait for every project to catch up.

Fixtures: `sh bin/check-skill-versions-test.sh`; the pre-commit hook runs them when `bin/` changes.

## Secrets

No secrets in this repository. A tool that needs one reads it from the environment or a password manager, and a template that needs one takes it from chezmoi's password manager functions, never as a literal.

`gitleaks` scans staged changes on every commit (`lefthook.yml`). To scan the whole history:

```sh
gitleaks git --redact
```

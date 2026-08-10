# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project doesn't tag releases yet: `main` is always the current version, and
you update with `git pull` followed by `./install.sh`. Changes therefore
accumulate under **Unreleased** until a tagging scheme exists.

## Unreleased

### Added

- **Indicator checklist in the installer.** `install.sh` now opens with a
  checkbox-style picker for which of the nine indicators should show. The boxes
  are seeded from your existing `~/.claude/statusline.conf` rather than from a
  fixed default, so re-running the installer shows what you actually have and
  never silently re-enables something you turned off. You type the numbers to
  flip; Enter alone changes nothing, and unchecking everything is refused.
- **`/statusline-config` skill.** Installed to `~/.claude/skills/` by
  `install.sh`, so it's available in Claude Code from the moment you finish
  installing. Running `/statusline-config` reads your current settings, asks
  what you want to change with a picker, and applies it: no path to remember,
  no config file to open. It also takes the request directly
  (`/statusline-config hide cpu and ram`). `uninstall.sh` removes it and leaves
  any other skill in that directory alone.
- **`statusline-config` command.** Reopens the indicator checklist and the
  reset-time format question on demand, without rerunning the installer or
  hand-editing the config: `statusline-config`, `statusline-config indicators`,
  or `statusline-config reset`. The installer copies it to
  `~/.claude/statusline-config` and offers to link it into `~/.local/bin` when
  that directory is already on your PATH; `uninstall.sh` removes both, and
  never touches a real file of that name that it didn't create. Without a
  terminal to read answers from it exits with an explanation instead of
  aborting halfway through a checklist nobody can answer.
- **Non-interactive settings API.** `statusline-config show`,
  `set-indicators NAME...` and `set-reset FORMAT [CLOCK]` read and write the
  config without prompting, which is what the skill drives and what makes a
  scripted or dotfiles-managed setup possible. Argument order for
  `set-indicators` is display order; both setters reject an unknown name or an
  empty list rather than writing a config the status line can't read.
- **Exact rate-limit reset times.** `five_hour` and `week` can now show the
  local clock time a limit resets, not just a countdown. Set `reset_format` in
  `~/.claude/statusline.conf` to `relative` (default, `reset 3h45m`),
  `absolute` (`reset 14:32`), or `both` (`reset 14:32 (3h45m)`). Absolute
  times carry a weekday prefix when the reset isn't today (`Mon 14:32`), so a
  bare time never reads as today when it's actually tomorrow.
- **`reset_clock` config key.** Picks the clock style used by
  `reset_format=absolute` and `reset_format=both`: `24h` (default, `14:32`) or
  `12h` (`2:32pm`).
- **Installer prompts for the reset display.** `install.sh` asks which reset
  format you want, and the clock style when that choice calls for one, showing
  a worked example beside each option instead of picking a silent default.
- **Timer-based refresh.** `install.sh` asks how often the status line should
  re-render and writes Claude Code's `statusLine.refreshInterval` (1 to 60
  seconds, off by default, 5s recommended) into `~/.claude/settings.json`, so
  time-based values stay current while you're idle rather than only updating
  when you send a message. Picking under 3 seconds with `cpu` or `ram` enabled
  prints a warning, since those indicators shell out to `top` and `vm_stat` on
  every render.

### Changed

- `install.sh` now merges into an existing `statusLine` object in
  `settings.json` instead of overwriting it wholesale. Re-running the installer
  keeps a `refreshInterval` you already set.
- The indicator and reset-time prompts live in `statusline-config`, which
  `install.sh` sources for them. Both paths run the same code instead of two
  copies drifting apart.

### Documentation

- README documents the reset-time and refresh-interval options, each with a
  table or worked example.
- README gains a "Configure which indicators show" section reproducing the
  checklist as it appears in the terminal, including what a toggle looks like
  before and after, and a section for the `statusline-config` command.
- README now states plainly that `context_window` and `rate_limits` only reach
  the status line after the session's first message, so a fresh session shows
  `Ctx --`, `5h --`, `Week --` until then. That's Claude Code's own behavior;
  no refresh interval works around it, and there's currently no supported way
  to make a `SessionStart` hook populate the fields earlier.

### Compatibility

- Defaults reproduce the previous output exactly. Existing `statusline.conf`
  files keep working untouched, since a missing `reset_format` falls back to
  `relative`.
- `refreshInterval` is ignored without error on Claude Code versions that
  don't support it, leaving event-driven updates as before.
- `statusline-config` and the installer's checklist target bash 3.2 and BSD
  userland (macOS's defaults) as well as GNU/Linux: no `readarray`, no
  associative arrays, no GNU-only `awk`/`sed`/`mktemp` flags.

## Initial version

The status line as first published, for reference:

- Model in use, bold, with the current reasoning effort glued beside it and
  color-coded per level.
- Context window usage as a percentage plus token count.
- 5-hour and weekly rate-limit usage with a relative time to reset.
- Git branch, marked with `*` when the working tree is dirty, and the current
  folder name.
- CPU and RAM usage of the machine.
- Plain-text config at `~/.claude/statusline.conf` controlling which
  indicators appear, their order, colors, thresholds, and the branch icon.
- Multi-row wrapping when the terminal is too narrow for one band.
- `install.sh` and `uninstall.sh`, both safe to re-run.

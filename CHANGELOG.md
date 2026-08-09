# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project doesn't tag releases yet: `main` is always the current version, and
you update with `git pull` followed by `./install.sh`. Changes therefore
accumulate under **Unreleased** until a tagging scheme exists.

## Unreleased

### Added

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

### Documentation

- README documents the reset-time and refresh-interval options, each with a
  table or worked example.
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

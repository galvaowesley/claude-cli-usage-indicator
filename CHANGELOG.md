# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project doesn't tag releases yet: `main` is always the current version, and
you update with `git pull` followed by `./install.sh`. Changes therefore
accumulate under **Unreleased** until a tagging scheme exists.

## Unreleased

### Added

- **Expandable detail panels.** `ccx` toggles a panel of extra rows under the
  band: `ccx` for a context breakdown, `ccx session` for a session summary,
  `ccx off` to collapse, `ccx status` to check. Toggling writes a local file
  and never interrupts Claude, so it works mid-generation and costs no
  tokens. Panels are off until you ask for one, and the state is shared by
  every open session.
- **Context panel.** Token usage split by cache behavior (fresh input, cache
  read, cache write, output, free space), each with its own color shared
  between its swatch and its slice of a stacked bar. Note this is not the
  breakdown `/context` shows: Claude Code exposes only the cache split to
  status line scripts, never the system-prompt/tools/skills/memory view, so
  the panel reports what is actually available. Before the session's first
  message, and just after `/compact`, no breakdown exists and the panel says
  so rather than showing zeroes.
- **Session panel.** Model, effort, permission mode, thinking, fast mode,
  cost, elapsed time and lines changed, followed by the keys that change
  them. It reports state rather than acting as a picker, because nothing a
  script, hook or settings file can do will change a running session's model,
  effort or permission mode. `Meta+P` and `Shift+Tab` already do that
  mid-generation.
- **Optional permission-mode hook.** Claude Code sends `permission_mode` to
  hooks but not to status lines, so the session panel can only show it with a
  companion hook that caches the value. `install.sh` offers to add it. The
  hook writes one word to one file, prints nothing, and always exits 0.
  Declining leaves the field showing `--`. Because it runs on tool use, the
  value can trail a `Shift+Tab` briefly, and anything older than five minutes
  is marked with a trailing `~`.
- **Panel colors are configurable** through `panel_border`, `panel_label`,
  and the five `cat_*` category keys.

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
- Hook registration is additive and idempotent. Re-running `install.sh` never
  stacks duplicate entries, and hooks belonging to other tools are passed
  through untouched, including malformed entries with no `hooks` array.
  `uninstall.sh` removes only entries whose command is this project's own
  script, and drops an event key or the `hooks` object only when its own
  removal is what emptied them.
- `strip_ansi` no longer shells out to `sed`. Panels multiply the row count
  and each row needs its visible width measured, so the measurement is done
  with parameter expansion instead of a process per row. Output is unchanged.

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
  `relative`, and the new `panel_*` and `cat_*` keys fall back to their
  defaults when absent.
- With no panel expanded, rendered output is byte-identical to the previous
  version for the same payload.
- Panels need a terminal at least 60 columns wide; narrower than that the
  status line says so rather than drawing a box that would wrap. Between 60
  and roughly 78 columns the session panel lays out in two columns.
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

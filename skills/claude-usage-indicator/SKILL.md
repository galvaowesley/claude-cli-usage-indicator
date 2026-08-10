---
name: claude-usage-indicator
description: Configure the claude-usage-indicator status line - which indicators show (model, effort, context, rate limits, dir, branch, cpu, ram), what order they appear in, how rate-limit reset times are displayed, how often the status line auto-refreshes, and restoring defaults. Use when the user asks to change, hide, show, reorder, speed up, slow down, reset, or check their status line.
user-invocable: true
allowed-tools:
  - Bash(~/.claude/claude-usage-indicator:*)
  - AskUserQuestion
---

# /claude-usage-indicator — configure the status line

Wraps the `~/.claude/claude-usage-indicator` command so the user picks options
from a menu instead of remembering a path and a set of flags.

Arguments passed: `$ARGUMENTS` (optional — may already name what to change,
e.g. "hide cpu and ram", "use exact clock times", "indicators")

## Step 1 — read the current state

Always start here, so the menu reflects what the user actually has:

```bash
~/.claude/claude-usage-indicator show
```

It prints `config:` and `settings:` (the two files involved), `indicators:`
(the visible ones, **in display order**), `available:` (every valid name),
`reset_format:`, `reset_clock:` and `refresh_interval:` (seconds, or `off`).

If the command is missing or reports the config was not found, the status
line isn't installed. Say so and point at `./install.sh` in the
[claude-cli-usage-indicator](https://github.com/galvaowesley/claude-cli-usage-indicator)
repo. Do not try to create the config by hand.

## Step 2 — find out what to change

If `$ARGUMENTS` already makes the intent unambiguous ("hide cpu and ram",
"switch to 12h clock"), skip straight to Step 3 and apply it.

Otherwise ask with **AskUserQuestion**. Offer these options:

- **Indicators** — which indicators show
- **Order** — the left-to-right order of the ones already showing
- **Reset time** — how 5h/weekly reset times are displayed
- **Refresh rate** — how often the status line re-renders on its own
- **Restore defaults** — undo everything back to the standard setup

Then ask the follow-up for whichever they picked:

**For indicators**, ask with `multiSelect: true`, one option per name in
`available:`, and make the description say what each shows:

| name | shows |
| --- | --- |
| `model` | Claude model in use, bold |
| `effort` | reasoning-effort level (when the model supports it) |
| `context` | % of context window used this session |
| `five_hour` | % of the 5-hour rate limit used |
| `week` | % of the weekly rate limit used |
| `dir` | current folder name |
| `branch` | git branch, `*` when the tree is dirty |
| `cpu` | system CPU usage % |
| `ram` | system RAM usage % |

Preselect nothing, but **state the current list in the question text** so the
user knows the starting point — for example: "Currently showing: model,
effort, context, five_hour, week, dir, branch. Pick every indicator you want
visible." Their selection replaces the list wholesale, so it must be the
complete set they want, not just the additions.

**For order**, an ordering is free-form, and AskUserQuestion cannot express
"drag these into place". So state the current order in the question text and
offer a few concrete arrangements as options, letting **Other** carry a
custom one. Build the options from what is actually visible, for example:

| option | order |
| --- | --- |
| Claude usage first | `context five_hour week` then identity, then machine |
| Identity first | `model effort dir branch` then usage |
| Machine last | current order, with `cpu ram` moved to the end |

Whatever they choose, the result must be a **permutation of the current
list**: same names, different sequence. If they ask to add or drop something
while reordering, that is an indicators change, so use `set-indicators`
instead and say why.

**For reset time**, ask which format: `relative` (`reset 3h45m`), `absolute`
(`reset 14:32`), or `both` (`reset 14:32 (3h45m)`). Only if they pick
`absolute` or `both`, ask the clock style: `24h` (`14:32`) or `12h`
(`2:32pm`). Never ask about the clock for `relative` — it has no effect there.

**For refresh rate**, offer `off` (event-driven only), `5` seconds
(recommended), `10` seconds, or a custom 1 to 60. State the current value
from `refresh_interval:`. If `cpu` or `ram` is in the visible list, say
plainly that they are the expensive part of a render, since each shells out
to `top`/`vm_stat`, and that below about 3 seconds the cost is noticeable.
Hiding those two is usually the better fix for a status line that feels slow.

**For restore defaults**, ask which scope, because they differ in what they
throw away:

- **Just the managed settings** — every indicator visible in the standard
  order, relative reset times, 24h clock, refresh off. Hand-edited colors,
  thresholds, separator and branch icon are left alone.
- **Everything** — the whole `statusline.conf` goes back to stock, colors and
  branch icon included. The old file is copied to `statusline.conf.bak`
  first, so say that.

Confirm before running either. This one discards choices the user made
deliberately, so never infer it from a vague "reset it" without checking
which scope they mean.

## Step 3 — apply

```bash
~/.claude/claude-usage-indicator set-indicators model effort context branch
~/.claude/claude-usage-indicator set-order context five_hour week model effort
~/.claude/claude-usage-indicator set-reset absolute 24h
~/.claude/claude-usage-indicator set-refresh 5          # or: off
~/.claude/claude-usage-indicator set-defaults           # or: set-defaults --all
```

Notes that matter:

- **Argument order is display order.** Keep the user's existing relative
  order unless they asked to reorder; append anything newly added at the
  position they implied, or at the end if they didn't say.
- **`set-order` deliberately refuses to change the set.** It requires exactly
  the names that are currently visible. That is what stops a reorder from
  quietly hiding an indicator, so treat its rejection as correct and reach
  for `set-indicators` instead.
- `effort` renders glued to `model` as a subtitle when it comes directly
  after it, so keep them adjacent unless the user wants otherwise.
- An empty indicator list is rejected by the command, and so should any
  request to hide everything — an empty band helps nobody. Ask what they
  want to keep.
- **`set-refresh` is the only one that writes `settings.json`**, and the only
  one needing `jq`. It merges into the existing `statusLine` object, so the
  installer's `command`/`type`/`padding` keys survive. If it reports `jq` is
  missing, relay that rather than editing the JSON by hand.
- Every command validates its input and exits non-zero with a message on a
  bad name, format or range. Surface that message rather than retrying
  blindly.

## Step 4 — confirm

Report what changed in plain terms, and set expectations about timing:
changes apply on the status line's **next render**. With a
`refreshInterval` set in `~/.claude/settings.json` that happens on its own
within seconds; without one, on the next thing Claude Code updates the
status line for (a new message, for instance).

Also worth saying once, if the user seems to expect otherwise: the config is
**one file per user account**, so this affects every open Claude Code
session on its next render, not only this one. There's no per-project
override.

## Scope

This skill covers which indicators show, their order, the reset-time
display, the refresh interval, and restoring defaults.

The one thing it does **not** change is **colors, thresholds, separator and
branch icon**. Those are keys in `~/.claude/statusline.conf`, documented in
comments at the top of that file. If the user asks for one, offer to edit
that file directly rather than pretending this command does it. Note that
`set-defaults --all` *does* reset them, since it restores the whole file, so
mention that if the user is trying to undo a color they regret.

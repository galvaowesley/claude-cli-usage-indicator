---
name: statusline-config
description: Configure the claude-usage-indicator status line - which indicators show (model, effort, context, rate limits, dir, branch, cpu, ram) and how rate-limit reset times are displayed. Use when the user asks to change, hide, show, reorder, or check their status line indicators, or asks about the reset time format.
user-invocable: true
allowed-tools:
  - Bash(~/.claude/statusline-config:*)
  - AskUserQuestion
---

# /statusline-config — configure the status line

Wraps the `~/.claude/statusline-config` command so the user picks options
from a menu instead of remembering a path and a set of flags.

Arguments passed: `$ARGUMENTS` (optional — may already name what to change,
e.g. "hide cpu and ram", "use exact clock times", "indicators")

## Step 1 — read the current state

Always start here, so the menu reflects what the user actually has:

```bash
~/.claude/statusline-config show
```

It prints `config:`, `indicators:` (the visible ones, in display order),
`available:` (every valid name), `reset_format:` and `reset_clock:`.

If the command is missing or reports the config was not found, the status
line isn't installed. Say so and point at `./install.sh` in the
[claude-cli-usage-indicator](https://github.com/galvaowesley/claude-cli-usage-indicator)
repo. Do not try to create the config by hand.

## Step 2 — find out what to change

If `$ARGUMENTS` already makes the intent unambiguous ("hide cpu and ram",
"switch to 12h clock"), skip straight to Step 3 and apply it.

Otherwise ask with **AskUserQuestion**. Offer these options:

- **Indicators** — which indicators show
- **Reset time** — how 5h/weekly reset times are displayed
- **Both** — walk through the two in order

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

**For reset time**, ask which format: `relative` (`reset 3h45m`), `absolute`
(`reset 14:32`), or `both` (`reset 14:32 (3h45m)`). Only if they pick
`absolute` or `both`, ask the clock style: `24h` (`14:32`) or `12h`
(`2:32pm`). Never ask about the clock for `relative` — it has no effect there.

## Step 3 — apply

```bash
~/.claude/statusline-config set-indicators model effort context branch
~/.claude/statusline-config set-reset absolute 24h
```

Notes that matter:

- **Argument order is display order.** Keep the user's existing relative
  order unless they asked to reorder; append anything newly added at the
  position they implied, or at the end if they didn't say.
- `effort` renders glued to `model` as a subtitle when it comes directly
  after it, so keep them adjacent unless the user wants otherwise.
- An empty indicator list is rejected by the command, and so should any
  request to hide everything — an empty band helps nobody. Ask what they
  want to keep.
- Both commands validate their input and exit non-zero with a message on a
  bad name or format. Surface that message rather than retrying blindly.

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

This skill covers indicators and the reset-time display. Things it does
**not** change, and where they live instead:

- **Colors, thresholds, separator, branch icon** — edit
  `~/.claude/statusline.conf` directly; every key is documented in comments
  at the top of that file.
- **Refresh interval** — `statusLine.refreshInterval` in
  `~/.claude/settings.json` (1–60 seconds, or absent for event-only updates).

If the user asks for one of those, point them at the right place, and offer
to make the edit directly rather than pretending this command does it.

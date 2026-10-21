---
name: agy-usage-indicator
description: Configure the Antigravity status line - which indicators show (model, effort, context, rate limits, dir, branch, cpu, ram), what order they appear in, how rate-limit reset times are displayed, how often the status line auto-refreshes, and restoring defaults. Use when the user asks to change, hide, show, reorder, speed up, slow down, reset, or check their status line in Antigravity.
user-invocable: true
---

# /agy-usage-indicator — configure the Antigravity status line

Wraps the `~/.gemini/antigravity-cli/agy-usage-indicator` command so the user picks options
from a menu instead of remembering a path and a set of flags.

Arguments passed: `$ARGUMENTS` (optional — may already name what to change,
e.g. "hide cpu and ram", "use exact clock times", "indicators")

## Step 1 — read the current state

Always start here, so the menu reflects what the user actually has:

```bash
~/.gemini/antigravity-cli/agy-usage-indicator show
```

It prints `config:` and `settings:` (the two files involved), `indicators:`
(the visible ones, **in display order**), `available:` (every valid name),
`reset_format:`, `reset_clock:` and `refresh_interval:` (seconds, or `off`).

If the command is missing or reports the config was not found, the status
line isn't installed. Say so and point at `./install.sh --agy` in the
[claude-cli-usage-indicator](https://github.com/galvaowesley/claude-cli-usage-indicator)
repo. Do not try to create the config by hand.

## Step 2 — find out what to change

If `$ARGUMENTS` already makes the intent unambiguous ("hide cpu and ram",
"switch to 12h clock"), skip straight to Step 3 and apply it.

Otherwise ask the user. Offer these options:

- **Indicators** — which indicators show
- **Order** — the left-to-right order of the ones already showing
- **Reset time** — how rate-limit reset times are displayed
- **Refresh rate** — how often the status line re-renders on its own
- **Restore defaults** — undo everything back to the standard setup

Then ask the follow-up for whichever they picked:

**For indicators**, ask one option per name in `available:`, with descriptions:

| name | shows |
| --- | --- |
| `model` | AI model in use, bold |
| `effort` | reasoning-effort level (when the model supports it) |
| `context` | % of context window used this session |
| `five_hour` | % of the 5-hour rate limit used |
| `week` | % of the weekly rate limit used |
| `dir` | current folder name |
| `branch` | git branch, `*` when the tree is dirty |
| `cpu` | system CPU usage % |
| `ram` | system RAM usage % |

State the current list in the question text so the user knows the starting point.
Their selection replaces the list wholesale, so it must be the complete set they want.

**For order**, state the current order and offer arrangements (e.g., usage first,
identity first, machine last, or custom order).

Whatever they choose, the result must be a **permutation of the current list**:
same names, different sequence.

**For reset time**, ask which format: `relative` (`reset 3h45m`), `absolute`
(`reset 14:32`), or `both` (`reset 14:32 (3h45m)`). Only if they pick
`absolute` or `both`, ask the clock style: `24h` (`14:32`) or `12h` (`2:32pm`).

**For refresh rate**, offer `off` (event-driven only), `5` seconds
(recommended), `10` seconds, or a custom 1 to 60. State the current value.
If `cpu` or `ram` is visible, note that below ~3 seconds the cost is noticeable.

**For restore defaults**, ask which scope:
- **Just the managed settings** — every indicator visible in standard order, relative reset times, 24h clock, refresh off.
- **Everything** — the whole `statusline.conf` back to stock, colors included. (Backup kept at `statusline.conf.bak`).

Confirm before running either.

## Step 3 — apply

```bash
~/.gemini/antigravity-cli/agy-usage-indicator set-indicators model effort context branch
~/.gemini/antigravity-cli/agy-usage-indicator set-order context five_hour week model effort
~/.gemini/antigravity-cli/agy-usage-indicator set-reset absolute 24h
~/.gemini/antigravity-cli/agy-usage-indicator set-refresh 5          # or: off
~/.gemini/antigravity-cli/agy-usage-indicator set-defaults           # or: set-defaults --all
```

Notes:
- **Argument order is display order.**
- `set-order` requires exactly the names currently visible.
- `effort` renders glued to `model` when placed directly after it.
- `set-refresh` updates `settings.json` via `jq`.

## Step 4 — confirm

Report what changed in plain terms. Changes apply on the status line's **next render**.
With `refreshInterval` set in `~/.gemini/antigravity-cli/settings.json`, that happens
on a timer; without one, on the next CLI event.

The config is at `~/.gemini/antigravity-cli/statusline.conf`.

## Scope

This skill covers which indicators show, their order, reset-time display,
refresh interval, and restoring defaults.

Visual styles (colors, thresholds, separator, branch icon) are edited in
`~/.gemini/antigravity-cli/statusline.conf`.

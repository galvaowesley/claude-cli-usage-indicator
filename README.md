<p align="center">
  <img src="assets/logo.svg" width="120" height="120" alt="claude-cli-usage-indicator logo">
</p>

<h1 align="center">claude-cli-usage-indicator</h1>

A configurable status line for [Claude Code](https://claude.com/claude-code) that shows, in a colored band under your prompt:

- **Model** in use, bold, with the current **reasoning effort** (`low`/`medium`/`high`/`xhigh`/`max`) glued next to it, color-coded
- **Context window** usage: percentage plus token count for the current session
- **5-hour** and **weekly** rate-limit usage, with time-to-reset shown as a relative countdown, an exact clock time, or both
- **Git branch** (with a `*` if the working tree is dirty) and current folder
- **CPU** and **RAM** usage of your machine

Claude-usage indicators and machine-usage indicators are tinted in two distinct colors so you can tell them apart at a glance. Everything, from which indicators show, to their order, to every color and threshold, is controlled by a plain-text config file. The band auto-wraps onto more than one row if your terminal is too narrow to fit everything.

All data comes from the JSON payload Claude Code's `statusLine` feature pipes to the script on every render: on session start/resume, on Claude Code's own update events, and (optionally) on a timer you configure (see [refresh interval](#configure-how-often-indicators-refresh)), so values stay fresh without you having to prompt Claude just to force a re-render. No undocumented APIs, no extra auth.

One caveat that's on Claude Code's side, not this script's: `context_window` and `rate_limits` are only included in that payload once you've sent your first message of the session. A brand-new session shows `Ctx --`, `5h --`, `Week --` until then, no matter how low you set the refresh interval. There's currently no supported way to make Claude Code populate them earlier.

Works on **Linux** and **macOS**.

## Example

<p align="center">
  <img src="assets/example.svg" alt="Example status line: model + effort, context, 5h and weekly rate limits, git branch, CPU/RAM" width="100%">
</p>

<p align="center"><sub>shown with the optional Nerd Font branch icon. The default install uses 🌿, see <a href="#configure-the-branch-icon">below</a>.</sub></p>

<p align="center">
  <img src="assets/claude-cli-usage-indicator_-_terminal.png" alt="claude-cli-usage-indicator running in a terminal" width="100%">
</p>

## Requirements

- `bash`
- [`jq`](https://jqlang.org/): `brew install jq` (macOS) or `apt install jq` / `dnf install jq` / `pacman -S jq` (Linux)
- `git`: needed to clone this repo, and to power the `branch` indicator once installed

Nothing else. The branch indicator uses an emoji (🌿) by default, so it works out of the box in any terminal, no extra fonts required.

## Install

```bash
git clone https://github.com/galvaowesley/claude-cli-usage-indicator.git
cd claude-cli-usage-indicator
./install.sh
```

This copies `statusline.sh` to `~/.claude/statusline.sh` and points Claude Code's `statusLine` setting at it (in `~/.claude/settings.json`), without touching anything else already in that file. It also installs the [`/statusline-config`](#change-the-settings-later-statusline-config) skill, so you can change your settings from inside Claude Code later without going near a config file. Re-running it is safe.

Partway through, the installer asks a few questions, each with an illustrated example of what you're picking:

- **which indicators to show**, as a checklist you tick through (see [below](#configure-which-indicators-show));
- which icon to use for the git branch indicator: the default emoji, or a sharper Nerd Font icon (only pick this if your terminal is already using a Nerd Font, see [below](#configure-the-branch-icon));
- how to show the 5-hour/weekly reset time: a relative countdown (`reset 3h45m`), the exact clock time (`reset 14:32`), or both, plus a 24h/12h clock style (see [below](#configure-the-reset-time-display));
- how often indicators should auto-refresh on their own: off by default, or every few seconds so reset countdowns and usage % feel live even while you're idle (see [below](#configure-how-often-indicators-refresh)).

You can always change any of these answers later by running [`/statusline-config`](#change-the-settings-later-statusline-config) inside Claude Code, or by editing the config file directly. Nothing here is one-shot.

Restart Claude Code, or open a new session, to see the status line.

## Configure

The first render auto-creates `~/.claude/statusline.conf` with every indicator enabled. Open it and edit freely; comments in the file document each option:

```
# one indicator name per line, in display order
model
effort
context
five_hour
week
dir
branch
cpu
ram

# visual style
bg=236
sep_char=┃
sep_color=73
color_low=114
color_mid=221
color_high=203
threshold_mid=50
threshold_high=80
claude_color=216
system_color=110
model_color=255
effort_low=178
effort_medium=114
effort_high=111
effort_xhigh=141
effort_max=203
branch_icon=🌿
reset_format=relative
reset_clock=24h
```

- **Remove a line** to hide that indicator; **reorder lines** to change display order.
- Colors are [256-color codes](https://www.ditig.com/256-colors-cheat-sheet).
- Changes apply on the next render, no restart needed.

### Change the settings later: `/statusline-config`

Two of the installer's questions, *which indicators show* and *how the reset time is displayed*, are the ones you're most likely to revisit. Inside Claude Code, just run:

```
/statusline-config
```

The installer sets this up for you, so there's nothing to remember and no path to type. It reads your current settings, asks what you want to change, and applies it:

```
> /statusline-config

  What would you like to change?
  ▸ Indicators    which indicators show in the band
    Reset time    how 5h/weekly reset times are displayed
    Both          walk through them in order

  Currently showing: model, effort, context, five_hour, week, dir, branch.
  Pick every indicator you want visible.
  ◻ model      Claude model in use, bold
  ◻ effort     reasoning-effort level
  ◻ context    % of context window used this session
  ...

-> set indicators in ~/.claude/statusline.conf: model effort context branch
```

You can also say what you want up front and skip the menu: `/statusline-config hide cpu and ram`, or `/statusline-config use exact clock times`.

#### From a plain shell

The same thing outside Claude Code is the `statusline-config` command. Interactive, asking the same questions as the installer:

```bash
statusline-config              # both questions, in order
statusline-config indicators   # only the indicator checklist
statusline-config reset        # only the reset-time format
```

Or non-interactive, which works anywhere including scripts:

```bash
statusline-config show                                   # print current settings
statusline-config set-indicators model effort context branch
statusline-config set-reset absolute 24h
```

The argument order for `set-indicators` *is* the display order. Both setters validate their input and refuse an empty list or an unknown name rather than writing a broken config.

If the installer didn't link it onto your PATH, use the full path (`~/.claude/statusline-config`) or add `alias statusline-config='~/.claude/statusline-config'` to your shell rc.

### What the settings apply to

The config lives at `~/.claude/statusline.conf`, one file per user account. That has two consequences worth knowing:

- **It works from any directory.** The path is absolute, so it doesn't matter which project the session is in, or where your shell happens to be.
- **It's global, not per project or per session.** There's one status line configuration for your whole account, so a change made anywhere takes effect in *every* open Claude Code session on its next render, not just the one you ran it from. There's currently no per-project override.

Changes apply on the next render. With `refreshInterval` set, that happens on its own within a few seconds; without it, on the next thing Claude Code updates the status line for.

### Configure which indicators show

The checklist below is what both `./install.sh` and `statusline-config indicators` show. The boxes aren't a fixed default: they're read from your current `~/.claude/statusline.conf`, so a fresh install starts with everything checked, and re-running it later shows what you actually have now.

```
Which indicators should the status line show? Checked ones reflect
/home/you/.claude/statusline.conf as it stands now.
  [x] 1) model      Claude model in use, bold
  [x] 2) effort     reasoning-effort level (only shown when the model supports it)
  [x] 3) context    % of context window used this session
  [x] 4) five_hour  % of your 5h rate-limit used
  [x] 5) week       % of your weekly rate-limit used
  [x] 6) dir        current folder name
  [x] 7) branch     git branch (+ * if the working tree is dirty)
  [x] 8) cpu        system CPU usage %
  [x] 9) ram        system RAM usage %
Numbers to toggle, space-separated (Enter = keep as checked above):
```

You type the **numbers you want to flip**, not the ones you want to keep. To drop the CPU and RAM indicators, for example:

```
Numbers to toggle, space-separated (Enter = keep as checked above): 8 9
-> set indicators in /home/you/.claude/statusline.conf: model effort context five_hour week dir branch
```

Running it again shows those two now unchecked, and typing `8 9` a second time puts them back:

```
  [x] 7) branch     git branch (+ * if the working tree is dirty)
  [ ] 8) cpu        system CPU usage %
  [ ] 9) ram        system RAM usage %
```

Notes:

- **Enter with no input keeps things exactly as they are**, which makes it safe to open the checklist just to look.
- Out-of-range numbers and non-numbers are ignored rather than treated as an error.
- Unchecking *everything* is refused (`that would leave no indicators, so the current list was kept instead`), since an empty band is never what someone means.
- The checklist sets *which* indicators show, not their order. Display order follows the order of the lines in the config file, so to reorder, move those lines around in `~/.claude/statusline.conf` directly.

### Configure the branch icon

The installer already asks you to pick one, but here's how to check or change it any time.

**1. Open the config file:**

```bash
open ~/.claude/statusline.conf        # macOS
xdg-open ~/.claude/statusline.conf    # Linux (or just open it in your editor)
```

**2. Find (or add) the `branch_icon=` line** and set it to one of:

- `branch_icon=🌿`: the default. Works in every terminal, no setup needed.
- `branch_icon=`: a sharper code-branch icon. Requires a Nerd Font (see below); without one it shows as `?` or a blank box.

Save the file. It applies on the next status line render, no restart needed.

**3. If you want the sharper icon, install and select a Nerd Font first:**

Many dev terminal setups already have one, for example if you use prompt themes like Powerlevel10k or Starship. If yours doesn't yet:

**On macOS:**

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

Then select it as your terminal's font:
1. Open Terminal (or iTerm2) and go to **Settings**.
2. Go to **Profiles → Text → Font → Change...**.
3. Pick **"JetBrainsMono Nerd Font"** from the list.
4. Close and reopen the terminal app (a new tab isn't enough).

**On Linux:**

```bash
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf \
  https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFontMono-Regular.ttf
fc-cache -fv
```

Then set it as your terminal emulator's font (the exact menu varies; in GNOME Terminal it's **Preferences → Profile → Text → Custom font**). Close and reopen the terminal app afterward.

Installing the font alone isn't enough in either case: the terminal app only uses it once you select it in its own settings.

### Configure the reset time display

`five_hour` and `week` show when your rate limit resets. Choose how by setting `reset_format` in `~/.claude/statusline.conf`:

| `reset_format=` | Looks like | Notes |
| --- | --- | --- |
| `relative` (default) | `reset 3h45m` | a countdown; also `1d2h` once it's more than a day out |
| `absolute` | `reset 14:32` | the exact local clock time; prefixed with the weekday (`Mon 14:32`) if the reset isn't today |
| `both` | `reset 14:32 (3h45m)` | exact time plus the countdown |

For `absolute`/`both`, `reset_clock` picks 24h (`14:32`, default) or 12h (`2:32pm`) style.

The installer asks for both up front. To change them later, run `/statusline-config` in Claude Code, or `statusline-config reset` in a shell to answer the same questions again:

```
How should the 5h/weekly rate-limit reset time be shown?
  1) Relative, default. Ex: reset 3h45m
  2) Exact clock time.  Ex: reset 14:32
  3) Both.              Ex: reset 14:32 (3h45m)
Choose 1, 2 or 3 [1]: 2

Clock style for that exact time?
  1) 24h, default. Ex: 14:32
  2) 12h.          Ex: 2:32pm
Choose 1 or 2 [1]: 1
-> set reset_format/reset_clock in /home/you/.claude/statusline.conf
```

The clock-style question only appears when your first answer calls for one. Editing the two config lines by hand works just as well; either way it applies on the next render.

### Configure how often indicators refresh

By default the status line only re-renders on Claude Code's own events (session start/resume, a new assistant message, `/compact`, permission-mode changes, vim-mode toggles). That's enough for most indicators, but anything time-based, like the reset countdown or usage % changing while you're idle, can go stale between those events.

Claude Code's `statusLine.refreshInterval` setting (1–60 seconds) fixes that by re-running the script on a timer too. The installer asks for a value (off by default; 5s is a good balance) and writes it straight into `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 5
  }
}
```

To change it later, edit `refreshInterval` in `settings.json` directly (or remove it to go back to event-only updates), or just re-run `./install.sh` and answer differently.

A lower interval means more indicator freshness but also more forked processes per minute. The `cpu`/`ram` indicators are the heaviest (each shells out to `top`/`vm_stat` or reads `/proc`), so if you enabled those, avoid going below ~3s.

`refreshInterval` needs a Claude Code version that supports it; on an older version it's simply ignored and the status line falls back to event-only updates, no error.

This only controls *how often* the script re-runs. It can't make `context_window`/`rate_limits` show up before your first message of the session, since Claude Code itself doesn't send that data until then (see the caveat near the top of this README).

## Uninstall

```bash
./uninstall.sh            # removes the script + statusLine setting, keeps your config
./uninstall.sh --purge    # also deletes statusline.conf and the CPU-usage cache
```

This also removes the `statusline-config` command, the `/statusline-config` skill, and, if the installer created one, the symlink in `~/.local/bin`. Other skills in `~/.claude/skills/` are left alone, as is a real file you put in `~/.local/bin` yourself under that name.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for what's changed. To update an existing install, `git pull` and re-run `./install.sh`.

## Why not a Claude Code plugin / marketplace listing?

Claude Code plugins can add commands, agents, hooks, and MCP servers, but the `statusLine` setting is a top-level key in `settings.json` that isn't currently exposed to plugins, so a marketplace plugin can't set it on install. A small installer script is the standard way status lines like this one are distributed today; that's what `install.sh` does here.

## Star History

[![Star History Chart](https://app.repohistory.com/api/svg?repo=galvaowesley/claude-cli-usage-indicator&background=0D1117&color=62C3F8)](https://app.repohistory.com/star-history)

## Credits

Inspired by a status-line idea shared by Rodrigo Belém on LinkedIn.

## License

MIT, see [LICENSE](LICENSE).

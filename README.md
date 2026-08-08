<p align="center">
  <img src="assets/logo.svg" width="120" height="120" alt="claude-cli-usage-indicator logo">
</p>

<h1 align="center">claude-cli-usage-indicator</h1>

A configurable status line for [Claude Code](https://claude.com/claude-code) that shows, in a colored band under your prompt:

- **Model** in use, bold, with the current **reasoning effort** (`low`/`medium`/`high`/`xhigh`/`max`) glued next to it, color-coded
- **Context window** usage: percentage plus token count for the current session
- **5-hour** and **weekly** rate-limit usage, with time-to-reset
- **Git branch** (with a `*` if the working tree is dirty) and current folder
- **CPU** and **RAM** usage of your machine

Claude-usage indicators and machine-usage indicators are tinted in two distinct colors so you can tell them apart at a glance. Everything, from which indicators show, to their order, to every color and threshold, is controlled by a plain-text config file. The band auto-wraps onto more than one row if your terminal is too narrow to fit everything.

All data comes from the JSON payload Claude Code's `statusLine` feature pipes to the script on every render. No undocumented APIs, no extra auth.

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
- `git` (optional, only needed for the `branch` indicator)

Nothing else. The branch indicator uses an emoji (🌿) by default, so it works out of the box in any terminal, no extra fonts required.

## Install

```bash
git clone https://github.com/galvaowesley/claude-cli-usage-indicator.git
cd claude-cli-usage-indicator
./install.sh
```

This copies `statusline.sh` to `~/.claude/statusline.sh` and points Claude Code's `statusLine` setting at it (in `~/.claude/settings.json`), without touching anything else already in that file. Re-running it is safe.

Partway through, the installer asks which icon you want for the git branch indicator: the default emoji, or a sharper Nerd Font icon (only pick this if your terminal is already using a Nerd Font, see [below](#configure-the-branch-icon)). You can always change your answer later by editing the config file directly.

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
```

- **Remove a line** to hide that indicator; **reorder lines** to change display order.
- Colors are [256-color codes](https://www.ditig.com/256-colors-cheat-sheet).
- Changes apply on the next render, no restart needed.

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

## Uninstall

```bash
./uninstall.sh            # removes the script + statusLine setting, keeps your config
./uninstall.sh --purge    # also deletes statusline.conf and the CPU-usage cache
```

## Why not a Claude Code plugin / marketplace listing?

Claude Code plugins can add commands, agents, hooks, and MCP servers, but the `statusLine` setting is a top-level key in `settings.json` that isn't currently exposed to plugins, so a marketplace plugin can't set it on install. A small installer script is the standard way status lines like this one are distributed today; that's what `install.sh` does here.

## Star History

[![Star History Chart](https://app.repohistory.com/api/svg?repo=galvaowesley/claude-cli-usage-indicator&background=0D1117&color=62C3F8)](https://app.repohistory.com/star-history)

## Credits

Inspired by a status-line idea shared by Rodrigo Belém on LinkedIn.

## License

MIT, see [LICENSE](LICENSE).

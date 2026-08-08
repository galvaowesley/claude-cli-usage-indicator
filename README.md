<p align="center">
  <img src="assets/logo.svg" width="120" height="120" alt="claude-cli-usage-indicator logo">
</p>

<h1 align="center">claude-cli-usage-indicator</h1>

A configurable status line for [Claude Code](https://claude.com/claude-code) that shows, in a colored band under your prompt:

- **Model** in use, bold, with the current **reasoning effort** (`low`/`medium`/`high`/`xhigh`/`max`) glued next to it, color-coded
- **Context window** usage — percentage + token count for the current session
- **5-hour** and **weekly** rate-limit usage, with time-to-reset
- **Git branch** (with a `*` if the working tree is dirty) and current folder
- **CPU** and **RAM** usage of your machine

Claude-usage indicators and machine-usage indicators are tinted in two distinct colors so you can tell them apart at a glance. Everything — which indicators show, in what order, and every color/threshold — is controlled by a plain-text config file. The band auto-wraps onto more than one row if your terminal is too narrow to fit everything.

All data comes from the JSON payload Claude Code's `statusLine` feature pipes to the script on every render — no undocumented APIs, no extra auth.

Works on **Linux** and **macOS**.

## Example

<p align="center">
  <img src="assets/example.svg" alt="Example status line: model + effort, context, 5h and weekly rate limits, git branch, CPU/RAM" width="100%">
</p>

<p align="center"><sub>shown with the optional Nerd Font branch icon — the default install uses 🌿, see <a href="#optional-sharper-branch-icon">below</a></sub></p>

## Requirements

- `bash`
- [`jq`](https://jqlang.org/) — `brew install jq` (macOS) or `apt install jq` / `dnf install jq` / `pacman -S jq` (Linux)
- `git` (optional, only needed for the `branch` indicator)

Nothing else — the branch indicator uses an emoji (🌿) by default, so it works out of the box in any terminal, no extra fonts required.

## Install

```bash
git clone https://github.com/galvaowesley/claude-cli-usage-indicator.git
cd claude-cli-usage-indicator
./install.sh
```

This copies `statusline.sh` to `~/.claude/statusline.sh` and points Claude Code's `statusLine` setting at it (in `~/.claude/settings.json`), without touching anything else already in that file. Re-running it is safe.

Restart Claude Code, or open a new session, to see the status line.

## Configure

The first render auto-creates `~/.claude/statusline.conf` with every indicator enabled. Open it and edit freely — comments in the file document each option:

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
- Changes apply on the next render — no restart needed.

### Optional: sharper branch icon

If your terminal font is a [Nerd Font](https://www.nerdfonts.com/) (many dev-focused terminal setups already use one, e.g. for prompt themes like Powerlevel10k or Starship), you can swap the default emoji for the crisper code-branch glyph:

```
branch_icon=
```

(that's a single Nerd Font character — paste it as-is into `statusline.conf`). If you don't already have a Nerd Font, this isn't required — the default emoji works everywhere. To install one: `brew install --cask font-jetbrains-mono-nerd-font` (macOS) or grab a `.ttf` from [nerdfonts.com](https://www.nerdfonts.com/font-downloads) (Linux, into `~/.local/share/fonts` + `fc-cache -f`) — then **select it in your terminal app's font settings** (installing alone isn't enough) and restart the terminal.

## Uninstall

```bash
./uninstall.sh            # removes the script + statusLine setting, keeps your config
./uninstall.sh --purge    # also deletes statusline.conf and the CPU-usage cache
```

## Why not a Claude Code plugin / marketplace listing?

Claude Code plugins can add commands, agents, hooks, and MCP servers — but the `statusLine` setting is a top-level key in `settings.json` that isn't currently exposed to plugins, so a marketplace plugin can't set it on install. A small installer script is the standard way status lines like this one are distributed today; that's what `install.sh` does here.

## Star History

[![Star History Chart](https://app.repohistory.com/api/svg?repo=galvaowesley/claude-cli-usage-indicator&background=0D1117&color=62C3F8)](https://app.repohistory.com/star-history)

## Credits

Inspired by a status-line idea shared by Rodrigo Belém on LinkedIn.

## License

MIT — see [LICENSE](LICENSE).

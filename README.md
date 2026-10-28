# Workspace Navigator

An Omarchy bar widget that makes workspace contents visible without switching
workspaces. Hover a workspace number to see live previews of its open windows,
click a preview to focus it, or right-click a workspace to open the full
overview.

The companion `double-super` helper toggles the separately installed
`omarchy-overview` plugin when the left Super key is tapped twice within 420 ms.

## Installation (Omarchy 4.5)

Install both plugins:

```bash
omarchy plugin add https://github.com/nidalJaafar/omarchy-overview.git --enable
omarchy plugin add https://github.com/nidalJaafar/omarchy-workspace-navigator.git --enable
```

If another overview version is already installed, back it up and remove it
through Omarchy's plugin manager before installing this fork, since both use
the same plugin ID.

In `~/.config/omarchy/shell.json`, replace `omarchy.workspaces` in the bar's
`left` section with `nidal.workspace-navigator`. Keep only one navigator entry
if enabling the plugin already added it. Add the double-Super binding below
to `~/.config/hypr/bindings.lua`, then run:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

Hover workspace buttons for window previews. Click a preview to focus a window,
right-click a workspace for the overview, or double-tap left Super after adding
the binding.

## Files installed outside this folder

The local setup replaces `omarchy.workspaces` with
`nidal.workspace-navigator` in `~/.config/omarchy/shell.json` and adds this
Hyprland binding to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SUPER_L", "Workspace overview (double-tap Super)", "${HOME}/.config/omarchy/plugins/nidal.workspace-navigator/double-super", { release = true })
```

The full overview dependency is available at
<https://github.com/nidalJaafar/omarchy-overview>.

## Omarchy 4.5 compatibility

Each bar reads Omarchy's watched `monitor-workspaces` state file, shows the
local 1–10 workspace numbers, and activates workspaces on that bar's monitor.
Guest workspaces from disconnected monitors remain available after the local
ones. The overview uses the same monitor assignments for previews, keyboard
navigation, scrolling, and workspace selection. It retains explicit
`overview.useWorkspaceMap` overrides when configured.

Use the linked overview fork for the matching compatibility fixes.

## Validation

Run `node tests/check.cjs` with `omarchy-overview` installed beside this plugin,
or set `OMARCHY_OVERVIEW_PATH` to that checkout. The checks cover saved monitor
assignments, monitor ID changes, guest workspaces, grid placement, and navigation.

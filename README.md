# Workspace Navigator

An Omarchy bar widget that makes workspace contents visible without switching
workspaces. Hover a workspace number to see live previews of its open windows,
click a preview to focus it, or right-click a workspace to open the full
overview.

The companion `double-super` helper toggles the separately installed
`omarchy-overview` plugin when the left Super key is tapped twice within 420 ms.

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

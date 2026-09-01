# kde-quickshell-dock

A Quickshell dock that shows your Plasma favourites and lets you drag them into
whatever order you like.

![the dock](docs/dock.png)

## What it does

- Reads the **Favorites** list out of Plasma's Application Launcher (Kickoff) —
  from the KActivities database Plasma actually keeps it in, not the stale copy
  in `appletsrc` (see [Where favourites live](#where-favourites-live)).
- Resolves `preferred://browser`, `preferred://filemanager`, `preferred://mailer`
  and `preferred://terminal` the same way Plasma does, via `kdeglobals` and
  `mimeapps.list`.
- Skips favourites whose application isn't installed, instead of showing a
  broken icon.
- **Drag to reorder.** Neighbours slide aside as you drag; the order is saved and
  restored on next launch.
- **Auto-hide** that never disappears completely — the dock slides down to a
  thin sliver at the screen edge and comes back when the pointer touches it.
- Click to launch, hover for the application name.
- Picks up favourite changes live — favourite something in Kickoff and it
  appears without a restart.
- Resolves icons through a fallback chain, so absolute-path and
  oddly-named icons still render (see [Icons](#icons)).
- Drawn as a single stroked path, so it blends into the screen edge with
  inverted corners (see [The dock outline](#the-dock-outline)).

## Requirements

- Quickshell (developed against 0.3.1)
- A compositor supporting `wlr-layer-shell` (KWin on Plasma 6 does)

## Running

```sh
qs -p ./shell.qml
```

To autostart it with your session:

```sh
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/quickshell-dock.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Quickshell Dock
Exec=qs -p $PWD/shell.qml
X-KDE-Wayland-Interfaces=zwlr_layer_shell_v1
EOF
```

## Configuration

Everything tunable lives in [Config.qml](Config.qml) — sizes, colours, hover
magnification, and:

| Property | Meaning |
| --- | --- |
| `source` | `"kickoff"` for launcher favourites, `"taskmanager"` for the task manager's pinned launchers |
| `autoHide` | Slide away when unused, leaving `peekHeight` px showing |
| `peekHeight` | How much of the dock stays visible while hidden |
| `triggerHeight` | Invisible pointer-catching strip along the screen edge |
| `hideDelay` | How long the pointer must be away before it hides |
| `edgeCorners` | Inverted corners flaring the dock into the screen edge |
| `border` / `borderWidth` | Hairline traced around the whole outline, fillets included |
| `cornerSize` | Radius of those corners |
| `peekFilletShare` | Height split between rounded corner and flare while peeking; lower = rounder |
| `backgroundColor` / `backgroundOpacity` | Dock background tint and translucency, kept separate from hex alpha |
| `reserveSpace` | `true` makes windows avoid the dock; `false` floats it on top |
| `hoverMagnify` | macOS-style icon zoom on hover |

Quickshell hot-reloads on save, so edits apply immediately.

## Auto-hide

With `autoHide` on, the dock gives up its floating gap and sits flush against
the screen edge — it has to touch the edge to be reachable by the pointer.
Hidden, only `peekHeight` px of its top remain visible.

The window itself stays full height the whole time; only the plate slides. What
moves with it is the input region (`mask`), so while the dock is hidden
everything except that thin sliver clicks straight through to the window
underneath. `triggerHeight` widens that strip a little beyond the visible
sliver, so the dock isn't fiddly to summon. It also won't slide away mid-drag.

Two details make revealing under a **stationary** pointer behave, both of which
took real debugging:

- The hover target is the fixed-position `body` container, not the plate. Qt only
  re-evaluates hover when a pointer event arrives, so a target that slid with the
  plate would move out from under a motionless pointer and report nothing
  hovered.
- That handler has to be an *ancestor* of the icons rather than a sibling,
  because the icons' `MouseArea`s consume hover events. As a sibling it saw
  nothing whenever the pointer was over an icon, and the dock revealed and then
  immediately hid again.

`revealGrace` is belt-and-braces on top: a brief window after revealing in which
a momentary "nothing hovered" is ignored rather than starting the hide timer.

## The dock outline

The whole dock is drawn as **one continuous path** — rounded top corners, sides,
and either the edge fillets or rounded bottom corners — built as SVG path data in
`Dock.silhouettePath` and rendered by a single `Shape`/`ShapePath`. Convex corners
sweep one way (SVG flag `1`), the concave fillets the other (`0`).

The **edge fillets** are inverted rounded corners — a square with a
quarter-circle bitten out — tucked against the screen edge either side of the
dock, so it looks like it grows out of the edge instead of ending in a hard
vertical line. Same trick GNOME Shell's "panel corners" use. `Rectangle.radius`
can't do it; that only rounds convex corners.

They're only drawn when the dock is genuinely flush with the edge, which is what
`autoHide` does — a floating dock has nothing to blend into, so it gets rounded
bottom corners instead. Either way the outline stays welded to the screen edge
while the dock peeks and expands, so the fillets don't slide off with the plate.

### Why one path

It started as a `Rectangle` plus two separate corner items. That works for fill,
but it can't be outlined: `Rectangle.border` applies to all four edges at once,
so the hairline ran down the plate's sides and straight across the join with the
fillets — precisely the seam the fillets exist to hide. The border had to be
switched off, which meant `Config.border` did nothing on the panel.

A single path strokes cleanly all the way round, fillets included, so
`border`/`borderWidth` work at every slide position. It also sidesteps
double-blending, which would otherwise show as a darker seam anywhere two
translucent shapes overlapped.

### Sharing the height

A continuous outline can't have the corner arc and the fillet arc overlap
vertically — the path would double back on itself. What peeks above the edge is
the plate's *top* edge, so on a thin sliver they're competing for the same few
pixels.

The **radius gets first claim** on the visible height, and the fillet takes
whatever is left, further capped by `peekFilletShare`. A very thin sliver is
therefore a pure rounded cap with no flare, and the flare grows in as the dock
expands past the radius. Prioritising the radius is deliberate: the alternative
leaves a thin sliver looking like a flat-ended box.

If you want a pronounced flare *while peeking* as well, the lever is a taller
`peekHeight` — there's simply no room for both in 8px.

All of it is driven off how much of the plate is showing, so it animates for free
along with `plate.y`.

Tune with `edgeCorners`, `cornerSize`, `peekFilletShare`, `radius`, `border` and
`borderWidth`.

## Icons

A single icon-theme lookup isn't enough in practice, so each entry gets a list
of candidates tried in order, falling through on load failure:

- `Icon=` is often an **absolute path** — DBeaver ships
  `Icon=/usr/share/dbeaver-ce/dbeaver.png` — which isn't a theme name at all and
  has to be loaded as a `file://` URL.
- Icon themes are inconsistent about naming. With `QT_QPA_PLATFORMTHEME=gtk3`,
  Qt resolves icons against the **GTK** icon theme, not Plasma's. Ant-Dark, for
  instance, ships `dbeaver.svg` but no `dbeaver-ce.svg`, and carries both
  `tilix.svg` and `com.gexperts.Tilix.svg`.

So `com.gexperts.Tilix` also tries `tilix`, `dbeaver-ce` also tries `dbeaver`,
and `code`/`vscode` also tries `visual-studio-code`, before finally falling back
to a generic executable icon.

Note that a correctly-resolved icon can still be hard to see: Tilix's own icon
is mid-grey, which reads as washed out against a dark dock. That's the
application's artwork, not a lookup failure.

## Where favourites live

This one is a trap. Kickoff has two places it can keep favourites, and the
obvious one is usually wrong.

Since Plasma 5.16 Kickoff stores favourites as **linked resources in the
KActivities statistics database**:

```
~/.local/share/kactivitymanagerd/resources/database
```

When it migrated it set `favoritesPortedToKAstats=true` in its applet config —
and left the old plain-text `favorites=` key behind, never updating it again. So
reading `appletsrc` gives you a snapshot from whenever the migration happened.
On the machine this was written against, the two disagreed completely: the stale
key still listed Discover, LibreOffice and Konsole, while the live favourites
were Tilix, DBeaver, a Chrome web app and Spotify.

So `PlasmaFavorites` reads the database whenever the applet reports the
migration, and only falls back to the `favorites=` key otherwise. The task
manager never migrated, so `source: "taskmanager"` always reads `appletsrc`.

Two practical notes:

- There's **no D-Bus method to enumerate** linked resources — the
  `ResourcesLinking` interface only offers `Is`/`Link`/`Unlink` — so the database
  really is the only source. It's read strictly read-only, via `sqlite3` or
  `python3`'s bundled engine, whichever is present. `kactivitymanagerd` holds it
  open in WAL mode, which permits concurrent readers.
- Favouriting something *does* emit D-Bus signals, so the dock subscribes to
  `ResourceLinkedToActivity`/`ResourceUnlinkedFromActivity` via `gdbus monitor`
  and re-queries, rather than polling.

`ResourceLink` has no ordering column, so favourites come back in link order
(`rowid`) — which is what Kickoff shows. Your own drag order takes over from
there anyway.

## How ordering works

Plasma owns *which* apps are favourites; this dock owns *the order*.

Dragging writes only to the dock's own state file
(`~/.local/state/quickshell/by-shell/<id>/dock-order.json`) and never touches
Plasma's config — plasmashell keeps that file in memory and would overwrite an
external edit anyway. Plasma's Favorites menu therefore keeps its own order.

On startup the two are merged: remembered positions first, then anything newly
favourited appended to the end. Un-favouriting an app drops it from the dock,
and its remembered position is discarded.

## Layout

| File | Role |
| --- | --- |
| [shell.qml](shell.qml) | Entry point; one dock per screen |
| [Dock.qml](Dock.qml) | The panel: layer-shell window, list, drag-reorder wiring, auto-hide, tooltip |
| [DockIcon.qml](DockIcon.qml) | One cell's visuals — highlight, icon, hover zoom |
| [IconResolver.qml](IconResolver.qml) | Builds the icon fallback chain |
| [PlasmaFavorites.qml](PlasmaFavorites.qml) | Picks the favourites source and resolves entries |
| [KAstatsFavorites.qml](KAstatsFavorites.qml) | Reads favourites from the KActivities database |
| [DockOrder.qml](DockOrder.qml) | Persists and merges the drag order |
| [Ini.qml](Ini.qml) | Small KConfig/INI reader |
| [Config.qml](Config.qml) | All the knobs |

## Notes

- `DesktopEntries` populates asynchronously and is empty on the frame you first
  touch it, so the favourite list is a reactive binding rather than a one-shot
  read.
- Applet ids in `appletsrc` are per-machine, so the Kickoff applet is found by
  scanning for the right `plugin=` with a non-empty list rather than a fixed id.

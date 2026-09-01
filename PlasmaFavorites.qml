pragma Singleton

import Quickshell
import Quickshell.Io

// Reads the Kickoff (Application Launcher) favourites straight out of Plasma's
// appletsrc and resolves each entry to a DesktopEntry.
//
// `ids` is the favourite list in Plasma's own order. It re-reads live: appletsrc
// is watched, so favouriting something in Kickoff shows up in the dock without
// a restart.
Singleton {
    id: root

    readonly property string appletsrcPath: Quickshell.env("HOME") + "/.config/plasma-org.kde.plasma.desktop-appletsrc"
    readonly property string kdeglobalsPath: Quickshell.env("HOME") + "/.config/kdeglobals"
    readonly property string mimeappsPath: Quickshell.env("HOME") + "/.config/mimeapps.list"

    // Favourite tokens straight out of appletsrc, and whether Plasma has
    // migrated this applet's favourites into the KActivities database.
    property var appletIds: []
    property bool portedToKAstats: false

    // Raw favourite tokens, in Plasma's order, e.g. "preferred://browser".
    //
    // Once Kickoff has ported to KAstats the appletsrc list is a stale
    // pre-migration snapshot, so the database wins. The task manager never
    // ported, so its launchers always come from appletsrc.
    readonly property var ids: {
        if (Config.source === "kickoff" && root.portedToKAstats && KAstatsFavorites.available)
            return KAstatsFavorites.ids;
        return root.appletIds;
    }

    // Resolved DesktopEntry list. Recomputes as the (lazily populated)
    // DesktopEntries model fills in, and whenever `ids` changes.
    readonly property var entries: {
        // Touching this both triggers the lazy scan and makes the binding
        // re-run each time another entry is discovered.
        const discovered = DesktopEntries.applications.values.length;

        const out = [];
        const seen = ({});

        for (const token of root.ids) {
            const id = root.resolveToken(token);
            if (!id || seen[id]) continue;

            const entry = root.lookup(id);
            if (!entry || entry.noDisplay) continue;

            seen[id] = true;
            out.push({ id: id, entry: entry });
        }

        return out;
    }

    // ---- token resolution -------------------------------------------------

    function resolveToken(token) {
        let t = String(token).trim();
        if (t === "") return "";

        // Task Manager style prefix: "applications:foo.desktop"
        if (t.startsWith("applications:")) t = t.slice("applications:".length);

        if (t.startsWith("preferred://")) {
            t = root.resolvePreferred(t.slice("preferred://".length));
            if (!t) return "";
        }

        // Unsupported favourite kinds (KAStats agents, contacts, ...).
        if (t.indexOf("://") >= 0) return "";

        if (t.endsWith(".desktop")) t = t.slice(0, -".desktop".length);
        return t;
    }

    function resolvePreferred(kind) {
        switch (kind) {
        case "browser":
            return root.kdeglobalsValue("BrowserApplication")
                || root.mimeDefault("x-scheme-handler/http")
                || "";
        case "filemanager":
            return root.mimeDefault("inode/directory") || "";
        case "mailer":
            return root.mimeDefault("x-scheme-handler/mailto") || "";
        case "terminal":
            return root.kdeglobalsValue("TerminalApplication") || "";
        default:
            return "";
        }
    }

    function lookup(id) {
        // byId wants the id without the .desktop suffix; heuristicLookup covers
        // values like kdeglobals' TerminalApplication=tilix, where the desktop
        // id is actually com.gexperts.Tilix.
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id) || null;
    }

    // ---- config file plumbing --------------------------------------------

    property var kdeglobals: ({})
    property var mimeapps: ({})

    function kdeglobalsValue(key) {
        const general = root.kdeglobals["[General]"];
        if (!general) return "";
        // KConfig may append a lock/immutable marker to the key.
        return general[key] || general[key + "[$i]"] || "";
    }

    function mimeDefault(mime) {
        for (const group of ["[Default Applications]", "[Added Associations]"]) {
            const g = root.mimeapps[group];
            if (!g || !g[mime]) continue;
            const first = g[mime].split(";").map(s => s.trim()).filter(s => s !== "")[0];
            if (first) return first;
        }
        return "";
    }

    readonly property var sourceSpecs: ({
        "kickoff": {
            plugins: ["org.kde.plasma.kickoff", "org.kde.plasma.kicker", "org.kde.plasma.kickerdash"],
            key: "favorites"
        },
        "taskmanager": {
            plugins: ["org.kde.plasma.taskmanager", "org.kde.plasma.icontasks"],
            key: "launchers"
        }
    })

    // Applet numbering is per-machine, and a typical setup has several matching
    // applets (a panel launcher plus a desktop one), only some of which hold a
    // list. So scan every applet of the right plugin and take the first
    // non-empty list rather than trusting a hardcoded applet id.
    function readAppletsrc(groups) {
        const spec = root.sourceSpecs[Config.source] ?? root.sourceSpecs["kickoff"];

        let ids = [];
        let ported = false;

        for (const header in groups) {
            const plugin = groups[header].plugin;
            if (!plugin || spec.plugins.indexOf(plugin) < 0) continue;

            const cfg = groups[header + "[Configuration][General]"];
            if (!cfg) continue;

            // Any matching applet reporting the migration means the plain-text
            // list below is a stale snapshot.
            if (cfg.favoritesPortedToKAstats === "true") ported = true;

            if (ids.length === 0 && cfg[spec.key]) {
                const list = Ini.splitList(cfg[spec.key]);
                if (list.length > 0) ids = list;
            }
        }

        root.appletIds = ids;
        root.portedToKAstats = ported;
    }

    FileView {
        path: root.appletsrcPath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.readAppletsrc(Ini.parse(this.text()))
        onLoadFailed: err => console.warn("dock: cannot read appletsrc:", err)
    }

    FileView {
        path: root.kdeglobalsPath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.kdeglobals = Ini.parse(this.text())
    }

    FileView {
        path: root.mimeappsPath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.mimeapps = Ini.parse(this.text())
    }
}

pragma Singleton

import Quickshell

// Minimal KConfig/INI reader.
//
// Groups are keyed by their raw bracketed header, so a nested Plasma group like
//   [Containments][2][Applets][3][Configuration][General]
// is addressable by concatenating the parent header with the child suffix.
// Malformed headers (Plasma's appletsrc does accumulate a few) simply become
// groups nobody looks up.
Singleton {
    id: root

    function parse(text) {
        const groups = ({});
        let current = "";

        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line === "" || line.startsWith("#") || line.startsWith(";")) continue;

            if (line.startsWith("[") && line.endsWith("]")) {
                current = line;
                if (groups[current] === undefined) groups[current] = ({});
                continue;
            }

            if (current === "") continue;

            const eq = line.indexOf("=");
            if (eq < 0) continue;

            groups[current][line.slice(0, eq).trim()] = line.slice(eq + 1);
        }

        return groups;
    }

    // KConfig escapes list separators as "\\," inside a value. Plasma writes
    // plain "," for favourites/launchers, so handle both.
    function splitList(value) {
        if (!value) return [];
        return value
            .replace(/\\,/g, ",")
            .split(",")
            .map(s => s.trim())
            .filter(s => s !== "");
    }
}

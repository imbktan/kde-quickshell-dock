pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Reads Kickoff's favourites out of the KActivities statistics database.
//
// Since Plasma 5.16 (and always in Plasma 6) Kickoff stores favourites as
// "linked resources" in this SQLite database, and sets
// favoritesPortedToKAstats=true in its applet config. The plain-text
// `favorites=` key left behind in plasma-org.kde.plasma.desktop-appletsrc is a
// pre-migration snapshot that Plasma never updates again, so reading it shows a
// list that can be years out of date.
//
// There's no D-Bus method to enumerate linked resources — the Linking interface
// only offers Is/Link/Unlink — so the database is the only source. It's read
// strictly read-only; kactivitymanagerd holds it open in WAL mode, which allows
// concurrent readers.
Singleton {
    id: root

    readonly property string dbPath: Quickshell.env("HOME")
        + "/.local/share/kactivitymanagerd/resources/database"

    // Favourite tokens in the order Kickoff linked them.
    property var ids: []
    // Stays false if the database can't be read, so callers can fall back.
    property bool available: false

    readonly property string sql:
        "SELECT targettedResource FROM ResourceLink"
        + " WHERE initiatingAgent = 'org.kde.plasma.favorites.applications'"
        + " AND usedActivity = ':global' ORDER BY rowid"

    // sqlite3 isn't always installed; python3 ships the same engine in its
    // standard library, so try both before giving up.
    readonly property string pythonFallback:
        "import sqlite3, sys\n"
        + "con = sqlite3.connect('file:' + sys.argv[1] + '?mode=ro', uri=True)\n"
        + "print('\\n'.join(r[0] for r in con.execute(sys.argv[2])))\n"

    readonly property string shellScript:
        'if command -v sqlite3 >/dev/null 2>&1; then exec sqlite3 -readonly "$1" "$2"; fi\n'
        + 'if command -v python3 >/dev/null 2>&1; then exec python3 -c "$3" "$1" "$2"; fi\n'
        + 'exit 127\n'

    function refresh() {
        query.running = false;
        query.running = true;
    }

    Process {
        id: query
        running: true
        command: ["sh", "-c", root.shellScript, "sh", root.dbPath, root.sql, root.pythonFallback]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(l => l.trim()).filter(l => l !== "");
                root.ids = lines;
                root.available = lines.length > 0;
            }
        }

        onExited: code => {
            if (code !== 0) {
                console.warn("dock: could not read KActivities favourites (exit " + code
                             + "); falling back to appletsrc");
                root.available = false;
            }
        }
    }

    // Favouriting something in Kickoff emits these, so the dock updates live
    // rather than waiting for a restart.
    Process {
        running: true
        command: ["gdbus", "monitor", "--session",
                  "--dest", "org.kde.ActivityManager",
                  "--object-path", "/ActivityManager/Resources/Linking"]

        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("ResourceLinkedToActivity") >= 0
                    || line.indexOf("ResourceUnlinkedFromActivity") >= 0) {
                    root.refresh();
                }
            }
        }
    }
}

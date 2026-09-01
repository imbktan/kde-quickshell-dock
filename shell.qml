//@ pragma UseQApplication

import Quickshell

ShellRoot {
    // One dock per screen.
    Variants {
        model: Quickshell.screens

        Dock {
            required property var modelData
            screen: modelData
        }
    }
}

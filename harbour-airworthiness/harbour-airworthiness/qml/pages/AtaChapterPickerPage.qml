import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Dialog {
    id: picker

    property string currentChapter
    signal chapterPicked(string chapter)

    // Only used for the picker lists; addAtaChapter()/renameAtaChapter()
    // write lookups.json (and saved hazards on rename), never anything else.
    HazardStore {
        id: lookupStore
    }

    Component {
        id: addChapterComponent
        Dialog {
            id: addDialog

            onAccepted: {
                var name = addField.text.trim()
                if (name.length > 0)
                    lookupStore.addAtaChapter(name)
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: column.height + Theme.paddingLarge

                Column {
                    id: column
                    width: parent.width

                    PageHeader { title: qsTr("Add ATA chapter") }

                    TextField {
                        id: addField
                        width: parent.width
                        // Same format as the built-in chapters,
                        // e.g. "94 - Weapons".
                        placeholderText: qsTr("e.g. 94 - Weapons")
                        label: qsTr("Chapter")
                    }
                }
            }
        }
    }

    Component {
        id: renameChapterComponent
        Dialog {
            id: renameDialog

            // Passed in when the dialog is pushed. Accepting with a new
            // text renames the custom chapter AND updates the hazards
            // that still store the old spelling.
            property string oldName

            onAccepted: {
                var name = renameField.text.trim()
                if (name.length > 0 && name !== renameDialog.oldName)
                    lookupStore.renameAtaChapter(renameDialog.oldName, name)
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: renameColumn.height + Theme.paddingLarge

                Column {
                    id: renameColumn
                    width: parent.width

                    PageHeader { title: qsTr("Rename ATA chapter") }

                    TextField {
                        id: renameField
                        width: parent.width
                        text: renameDialog.oldName
                        label: qsTr("Chapter")
                    }
                }
            }
        }
    }

    SilicaListView {
        anchors.fill: parent

        // Rebuilt automatically when custom chapters are added, renamed or
        // removed or when the current value changes ("__add__" is a pseudo
        // entry, never saved).
        model: {
            var entries = []
            entries.push({ value: "", label: qsTr("Not set"), custom: false })
            var known = lookupStore.ataChapters
            var customs = lookupStore.customAtaChapters
            // Keep a value saved by an older version selectable even if it
            // is free text that is not in the chapter list.
            if (picker.currentChapter !== ""
                    && known.indexOf(picker.currentChapter) === -1)
                entries.push({ value: picker.currentChapter,
                               label: picker.currentChapter, custom: false })
            for (var i = 0; i < known.length; ++i)
                entries.push({ value: known[i], label: known[i],
                               custom: customs.indexOf(known[i]) !== -1 })
            entries.push({ value: "__add__",
                          label: qsTr("Add custom chapter..."), custom: false })
            return entries
        }
        header: PageHeader { title: qsTr("System (ATA)") }

        delegate: ListItem {
            id: listItem

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData.label
                color: modelData.value === picker.currentChapter
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }

            // Press and hold: only user-added chapters can be renamed or
            // removed; the built-in list stays stable for saved hazards.
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Rename")
                    visible: modelData.custom
                    onClicked: pageStack.push(renameChapterComponent,
                                             { oldName: modelData.value })
                }
                MenuItem {
                    text: qsTr("Delete")
                    visible: modelData.custom
                    onClicked: listItem.remorseAction(qsTr("Deleting"), function() {
                        lookupStore.removeAtaChapter(modelData.value)
                    })
                }
            }

            onClicked: {
                if (modelData.value === "__add__") {
                    pageStack.push(addChapterComponent)
                    return
                }
                picker.chapterPicked(modelData.value)
                picker.accept()
            }
        }
    }
}

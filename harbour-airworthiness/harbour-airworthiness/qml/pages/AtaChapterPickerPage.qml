import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Dialog {
    id: picker

    property string currentChapter
    signal chapterPicked(string chapter)

    // Only used for the picker lists; addAtaChapter() writes lookups.json,
    // never hazards.json.
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

    SilicaListView {
        anchors.fill: parent

        // Rebuilt automatically when custom chapters are added or the
        // current value changes ("__add__" is a pseudo entry, never saved).
        model: {
            var entries = []
            entries.push({ value: "", label: qsTr("Not set") })
            var known = lookupStore.ataChapters
            // Keep a value saved by an older version selectable even if it
            // is free text that is not in the chapter list.
            if (picker.currentChapter !== ""
                    && known.indexOf(picker.currentChapter) === -1)
                entries.push({ value: picker.currentChapter,
                               label: picker.currentChapter })
            for (var i = 0; i < known.length; ++i)
                entries.push({ value: known[i], label: known[i] })
            entries.push({ value: "__add__", label: qsTr("Add custom chapter...") })
            return entries
        }
        header: PageHeader { title: qsTr("System (ATA)") }

        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData.label
                color: modelData.value === picker.currentChapter
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
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

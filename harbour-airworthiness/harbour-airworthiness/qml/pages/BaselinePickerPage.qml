import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Dialog {
    id: picker

    property string currentBaseline
    // true: opened from the main list menu as a filter. The empty value
    // then means "All baselines" (no filtering). false: opened from the
    // edit page, where the empty value means "Not specified".
    property bool filterMode: false
    signal baselinePicked(string baseline)

    // Only used for the picker lists; addBaseline() writes lookups.json,
    // never hazards.json.
    HazardStore {
        id: lookupStore
    }

    Component {
        id: addBaselineComponent
        Dialog {
            id: addDialog

            onAccepted: {
                var name = addField.text.trim()
                if (name.length > 0)
                    lookupStore.addBaseline(name)
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: column.height + Theme.paddingLarge

                Column {
                    id: column
                    width: parent.width

                    PageHeader { title: qsTr("Add baseline") }

                    TextField {
                        id: addField
                        width: parent.width
                        placeholderText: qsTr("e.g. DEF STAN 00-970")
                        label: qsTr("Baseline")
                    }
                }
            }
        }
    }

    SilicaListView {
        anchors.fill: parent

        // Rebuilt automatically when custom baselines are added or the
        // current value changes ("__add__" is a pseudo entry, never saved).
        model: {
            var entries = []
            entries.push({
                value: "",
                label: picker.filterMode ? qsTr("All baselines")
                                         : qsTr("Not specified")
            })
            var known = lookupStore.baselines
            if (picker.currentBaseline !== ""
                    && known.indexOf(picker.currentBaseline) === -1)
                entries.push({ value: picker.currentBaseline,
                               label: picker.currentBaseline })
            for (var i = 0; i < known.length; ++i)
                entries.push({ value: known[i], label: known[i] })
            entries.push({ value: "__add__", label: qsTr("Add custom baseline...") })
            return entries
        }
        header: PageHeader {
            title: picker.filterMode
                  ? qsTr("Filter: certification baseline")
                  : qsTr("Certification baseline")
        }

        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData.label
                color: modelData.value === picker.currentBaseline
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
            onClicked: {
                if (modelData.value === "__add__") {
                    pageStack.push(addBaselineComponent)
                    return
                }
                picker.baselinePicked(modelData.value)
                picker.accept()
            }
        }
    }
}

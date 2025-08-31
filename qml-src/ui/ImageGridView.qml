import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: imageGridView
    color: "white"

    property var articleImages: []
    property real scaleFactor: 1.5
    property string articleTitle: ""

    signal backClicked()
    signal imageSelected(int index)

    signal close
        function unloading() {
            console.log("Child component unloading")
        }

    FontLoader {
        id: bookerlyRegular
        source: "qrc:/fonts/Bookerly-Regular.ttf"
    }

    FontLoader {
        id: bookerlyBold
        source: "qrc:/fonts/Bookerly-Bold.ttf"
    }

    Rectangle {
        id: imageHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80 * scaleFactor
        color: "#f5f5f5"
        border.color: "#e0e0e0"
        border.width: 1

        Button {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10 * scaleFactor
            width: 60 * scaleFactor
            height: 60 * scaleFactor

            background: Rectangle {
                color: parent.pressed ? "#e0e0e0" : "transparent"
                radius: 8
            }

            Image {
                anchors.centerIn: parent
                width: 24 * scaleFactor
                height: 24 * scaleFactor
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><path d='M19 12H5M12 19l-7-7 7-7'/></svg>"
            }

            onClicked: {
                console.log("Back button clicked")
                imageGridView.backClicked()
            }
        }

        Text {
            anchors.centerIn: parent
            text: articleImages.length + " Images"
            font.family: bookerlyBold.name
            font.pointSize: 16 * scaleFactor
            font.bold: true
        }
    }


    // Scrollable grid container
    Flickable {
        id: gridFlickable
        anchors.top: imageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20 * scaleFactor

        contentWidth: width
        contentHeight: gridFlow.height + 40 * scaleFactor
        clip: true

        Flow {
            id: gridFlow
            width: parent.width
            spacing: 20 * scaleFactor

            // Calculate how many columns fit
            property int itemWidth: 280 * scaleFactor
            property int columns: Math.floor((width + spacing) / (itemWidth + spacing))
            property int actualItemWidth: columns > 0 ? Math.floor((width - (columns - 1) * spacing) / columns) : itemWidth

            Repeater {
                model: articleImages

                Button {
                    width: gridFlow.actualItemWidth
                    height: 280 * scaleFactor

                    background: Rectangle {
                        color: parent.pressed ? "#f0f0f0" : "white"
                        border.color: parent.pressed ? "#007acc" : "#ddd"
                        border.width: parent.pressed ? 3 : 2
                        radius: 12 * scaleFactor

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 3 * scaleFactor
                            anchors.leftMargin: 3 * scaleFactor
                            radius: parent.radius
                            color: "#00000015"
                            z: -1
                        }
                    }

                    contentItem: Column {
                        anchors.fill: parent
                        anchors.margins: 15 * scaleFactor
                        spacing: 12 * scaleFactor

                        Rectangle {
                            width: parent.width
                            height: 160 * scaleFactor
                            color: "#f8f9fa"
                            radius: 8 * scaleFactor
                            clip: true

                            Image {
                                id: imageItem
                                anchors.fill: parent
                                anchors.margins: 5 * scaleFactor
                                source: modelData.src || ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (imageItem.status === Image.Loading) return "Loading..."
                                    if (imageItem.status === Image.Error) return "Failed to load"
                                    if (imageItem.status === Image.Null) return "📷"
                                    return ""
                                }
                                font.family: bookerlyRegular.name
                                font.pointSize: imageItem.status === Image.Null ? 24 * scaleFactor : 12 * scaleFactor
                                color: imageItem.status === Image.Error ? "#e74c3c" : "#999"
                                visible: imageItem.status !== Image.Ready
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Image " + (index + 1)
                            font.family: bookerlyBold.name
                            font.pointSize: 14 * scaleFactor
                            font.bold: true
                            color: "#333"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            width: parent.width
                            text: {
                                var caption = modelData.caption || modelData.alt || "Tap to view full size"
                                return caption.length > 80 ? caption.substring(0, 80) + "..." : caption
                            }
                            font.family: bookerlyRegular.name
                            font.pointSize: 11 * scaleFactor
                            color: "#666"
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    onClicked: {
                        console.log("Image clicked:", index)
                        imageGridView.imageSelected(index)
                    }
                }
            }
        }
    }

    // Debug info
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10 * scaleFactor
        text: "Grid: " + gridFlow.columns + " cols, " + articleImages.length + " images"
        font.pointSize: 8 * scaleFactor
        color: "#999"
    }
}

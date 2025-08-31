import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: imageViewer
    color: "black"

    property var articleImages: []
    property int selectedImageIndex: -1
    property real scaleFactor: 1.5

    signal backClicked()

    signal close
        function unloading() {
            console.log("Child component unloading")
        }

    FontLoader {
        id: bookerlyRegular
        source: "qrc:/fonts/Bookerly-Regular.ttf"
    }

    Image {
        id: mainImage
        anchors.centerIn: parent
        source: selectedImageIndex >= 0 && selectedImageIndex < articleImages.length ? 
                articleImages[selectedImageIndex].src : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true

        property bool isLandscape: sourceSize.width > sourceSize.height && sourceSize.width > 0
        property bool shouldRotate: isLandscape && parent.width < parent.height

        width: shouldRotate ? parent.height : parent.width
        height: shouldRotate ? parent.width : parent.height

        rotation: shouldRotate ? 90 : 0

        transformOrigin: Item.Center

        // Loading indicator
        Rectangle {
            anchors.centerIn: parent
            width: 100 * scaleFactor
            height: 100 * scaleFactor
            color: "#333"
            radius: 8 * scaleFactor
            visible: parent.status === Image.Loading

            Text {
                anchors.centerIn: parent
                text: "Loading..."
                color: "white"
                font.pointSize: 12 * scaleFactor
            }
        }

        // Error state
        Rectangle {
            anchors.centerIn: parent
            width: 200 * scaleFactor
            height: 100 * scaleFactor
            color: "#333"
            radius: 8 * scaleFactor
            visible: parent.status === Image.Error

            Text {
                anchors.centerIn: parent
                text: "Failed to load image"
                color: "white"
                font.pointSize: 12 * scaleFactor
            }
        }
    }

    Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20 * scaleFactor
        width: 50 * scaleFactor
        height: 50 * scaleFactor

        background: Rectangle {
            color: parent.pressed ? "#666" : "#333"
            radius: 25 * scaleFactor
            opacity: 0.8
        }

        contentItem: Image {
            anchors.centerIn: parent
            width: 20 * scaleFactor
            height: 20 * scaleFactor
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2' stroke-linecap='round'><path d='M18 6L6 18M6 6l12 12'/></svg>"
        }

        onClicked: imageViewer.backClicked()
    }


    // Alternative close method - tap anywhere
    MouseArea {
        anchors.fill: parent
        z: -1 
        onClicked: imageViewer.backClicked()
    }

}

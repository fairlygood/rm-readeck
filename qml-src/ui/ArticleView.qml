import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: articleView
    color: "#ffffff"

    property var article: null
    property real scaleFactor: 1.5
    property int currentPage: 0
    property int totalPages: 0
    property var articleImages: article ? (article.images || []) : []
    property int selectedImageIndex: -1
    property string currentView: "article" // "article", "imageGrid", "imageViewer"

    signal backClicked()
    signal markAsReadClicked(int articleId)

    FontLoader {
        id: bookerlyRegular
        source: "qrc:/fonts/Bookerly-Regular.ttf"
    }

    onArticleChanged: {
        if (article) {
            currentPage = 0
            currentView = "article"
            calculatePages()
        }
    }

    function formatContent(content) {
    if (!content) return "No content"
    
    // If content already has HTML tags, preserve them
    if (content.includes('<h1>') || content.includes('<h2>') || content.includes('<h3>')) {
        return content.replace(/<p>/g, '<p style="margin-bottom: 0.8em;">')
    }
    
    var paragraphs = content.split('\n\n')
    var formatted = paragraphs.map(p => {
        if (p.trim()) {
            var trimmed = p.trim()
            
            if (trimmed.length < 60 && !trimmed.includes('.') && trimmed.split(' ').length < 8) {

                var isLikelyHeader = /^[A-Z]/.test(trimmed) && trimmed.length < 50
                
                if (isLikelyHeader) {
                    return `<h3 style="margin-top: 1em; margin-bottom: 0.5em; font-weight: bold;">${trimmed}</h3>`
                }
            }
            
            // Regular paragraph
            return `<p style="margin-bottom: 0.8em;">${p.replace(/\n/g, '<br>')}</p>`
        }
        return ''
    }).join('')
    
    return formatted
}

    function calculatePages() {
        if (!article || currentView !== "article") return

        Qt.callLater(function() {
            if (articleContentView.visible && mainFlickable && mainContentText) {
                var pageHeight = mainFlickable.height
                var contentHeight = mainContentText.height

                var actualLineHeight = contentHeight / getEstimatedLineCount()

                var linesPerPage = Math.floor(pageHeight / actualLineHeight)
                var totalLines = getEstimatedLineCount()

                totalPages = Math.ceil(totalLines / linesPerPage)

                console.log("Page height:", pageHeight)
                console.log("Content height:", contentHeight)
                console.log("Actual line height:", actualLineHeight)
                console.log("Lines per page:", linesPerPage)
                console.log("Total pages:", totalPages)
            }
        })
    }

    function getEstimatedLineCount() {
        if (!article || !article.content) return 0

        // Count actual lines in the content more accurately
        var content = article.content
        var paragraphs = content.split('\n\n')
        var totalLines = 0

        paragraphs.forEach(function(paragraph) {
            if (paragraph.trim()) {
                var chars = paragraph.length
                var avgCharsPerLine = 80 // Rough estimate for 18pt font
                var linesInParagraph = Math.ceil(chars / avgCharsPerLine)
                totalLines += linesInParagraph
                totalLines += 0.5 // Add space between paragraphs
            }
        })

        return Math.ceil(totalLines)
    }

    function getActualLineHeight() {
        if (mainContentText && mainContentText.height > 0) {
            return mainContentText.height / getEstimatedLineCount()
        }
        return 37.422 
    }

    function nextPage() {
        if (currentView === "article" && currentPage < totalPages - 1) {
            currentPage++
            if (mainFlickable && mainContentText) {
                var pageHeight = mainFlickable.height
                var actualLineHeight = getActualLineHeight()

                var linesPerPage = Math.floor(pageHeight / actualLineHeight)

                var targetLine = currentPage * linesPerPage
                var targetY = targetLine * actualLineHeight

                mainFlickable.contentY = Math.min(targetY, mainFlickable.contentHeight - mainFlickable.height)
            }
        }
    }

    function previousPage() {
        if (currentView === "article" && currentPage > 0) {
            currentPage--
            if (mainFlickable && mainContentText) {
                var pageHeight = mainFlickable.height
                var actualLineHeight = getActualLineHeight()

                var linesPerPage = Math.floor(pageHeight / actualLineHeight)

                var targetLine = currentPage * linesPerPage
                var targetY = targetLine * actualLineHeight

                mainFlickable.contentY = Math.max(0, targetY)
            }
        }
    }

    // Main article view
    Rectangle {
        id: articleContentView
        anchors.fill: parent
        color: "#ffffff"
        visible: currentView === "article"

        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 100 * scaleFactor
            color: "#f5f5f5"
            border.color: "#e0e0e0"
            border.width: 1

            Row {
                id: leftButtons
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10 * scaleFactor
                spacing: 5 * scaleFactor

                Button {
                    id: backButton
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

                    onClicked: articleView.backClicked()
                }

                Button {
                    id: imagesButton
                    width: 60 * scaleFactor
                    height: 60 * scaleFactor
                    visible: articleImages.length > 0

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : "transparent"
                        radius: 8
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20 * scaleFactor
                            height: 20 * scaleFactor
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><circle cx='8.5' cy='8.5' r='1.5'/><path d='M21 15l-5-5L5 21'/></svg>"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: articleImages.length.toString()
                            font.pointSize: 10 * scaleFactor
                            color: "#666"
                        }
                    }

                    onClicked: {
                        currentView = "imageGrid"
                    }
                }
            }

            // Right side button
            Button {
                id: markReadButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10 * scaleFactor
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
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><path d='M20 6L9 17l-5-5'/></svg>"
                }

                onClicked: {
                    if (article && article.id) {
                        articleView.markAsReadClicked(article.id)
                    }
                }
            }

            Text {
                anchors.left: leftButtons.right
                anchors.right: markReadButton.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 15 * scaleFactor
                text: article ? article.title : ""
                font.pointSize: 16 * scaleFactor
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        Flickable {
            id: mainFlickable
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: 60 * scaleFactor
            anchors.bottomMargin: 50 * scaleFactor

            contentWidth: width
            contentHeight: mainContentText.height
            clip: true

            interactive: true

            flickDeceleration: 1500
            maximumFlickVelocity: 2500

            signal close
                function unloading() {
                    console.log("Child component unloading")
                }

            Text {
                id: mainContentText
                width: parent.width
                text: article ? formatContent(article.content) : "No content"
                font.pointSize: 18 * scaleFactor
                font.family: bookerlyRegular.name
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                horizontalAlignment: Text.AlignJustify
                lineHeight: 1.1
                color: "#000000"

                onHeightChanged: {
                    console.log("Text height changed:", height)
                    console.log("Estimated line count:", articleView.getEstimatedLineCount())
                    console.log("Actual line height:", height / articleView.getEstimatedLineCount())
                    articleView.calculatePages()
                }
            }

            onContentYChanged: {
                if (totalPages > 0) {
                    var actualLineHeight = articleView.getActualLineHeight()
                    var linesPerPage = Math.floor(height / actualLineHeight)
                    var currentLine = Math.round(contentY / actualLineHeight)
                    var newPage = Math.floor(currentLine / linesPerPage)

                    if (newPage !== currentPage && newPage >= 0 && newPage < totalPages) {
                        currentPage = newPage
                    }
                }
            }
        }

        Rectangle {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60 * scaleFactor
            color: "#f5f5f5"
            border.color: "#e0e0e0"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 20 * scaleFactor

                Button {
                    width: 60 * scaleFactor
                    height: 40 * scaleFactor
                    enabled: currentPage > 0

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : "transparent"
                        radius: 8
                        opacity: parent.enabled ? 1.0 : 0.3
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24 * scaleFactor
                        height: 24 * scaleFactor
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><path d='M19 12H5M12 19l-7-7 7-7'/></svg>"
                        opacity: parent.enabled ? 1.0 : 0.3
                    }

                    onClicked: articleView.previousPage()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: totalPages > 0 ? `Page ${currentPage + 1} of ${totalPages}` : ""
                    font.pointSize: 12 * scaleFactor
                    color: "#666666"
                }

                Button {
                    width: 60 * scaleFactor
                    height: 40 * scaleFactor
                    enabled: currentPage < totalPages - 1

                    background: Rectangle {
                        color: parent.pressed ? "#e0e0e0" : "transparent"
                        radius: 8
                        opacity: parent.enabled ? 1.0 : 0.3
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24 * scaleFactor
                        height: 24 * scaleFactor
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><path d='M5 12h14M12 5l7 7-7 7'/></svg>"
                        opacity: parent.enabled ? 1.0 : 0.3
                    }

                    onClicked: articleView.nextPage()
                }
            }
        }

        Keys.onPressed: {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Space) {
                articleView.nextPage()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                articleView.previousPage()
                event.accepted = true
            }
        }

        // Touch/mouse navigation on sides
        MouseArea {
            anchors.fill: mainFlickable
            z: -1  // Put it behind the flickable so it doesn't interfere
            onClicked: {
                if (mouse.x > width / 2) {
                    articleView.nextPage()
                } else {
                    articleView.previousPage()
                }
            }
        }

        Component.onCompleted: {
            focus = true
        }
    }

    ImageGridView {
        id: imageGridView
        anchors.fill: parent
        visible: currentView === "imageGrid"

        articleImages: articleView.articleImages
        scaleFactor: articleView.scaleFactor
        articleTitle: article ? article.title : ""

        onBackClicked: {
            currentView = "article"
        }

        onImageSelected: function(index) {
            selectedImageIndex = index
            currentView = "imageViewer"
        }
    }

    ImageViewer {
        id: imageViewer
        anchors.fill: parent
        visible: currentView === "imageViewer"

        articleImages: articleView.articleImages
        selectedImageIndex: articleView.selectedImageIndex
        scaleFactor: articleView.scaleFactor

        onBackClicked: {
            currentView = "imageGrid"
        }
    }
}

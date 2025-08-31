import QtQuick 2.15
import QtQuick.Controls 2.15
import net.asivery.AppLoad 1.0

Rectangle {
    width: Screen.width
    height: Screen.height
    visible: true

    property var articlesData: null
    property int articlesPerPage: 8
    property bool showingArticle: false
    property var currentArticle: null
    property real scaleFactor: 1.5

    signal close

    function unloading() {
        console.log("We're unloading!");
    }


    FontLoader {
        id: bookerlyRegular
        source: "qrc:/fonts/Bookerly-Regular.ttf"
    }

    FontLoader {
        id: bookerlyBold
        source: "qrc:/fonts/Bookerly-Bold.ttf"
    }

    AppLoad {
        id: endpoint  // Changed from 'appload' to 'backend'
        applicationID: "rm-readeck"

        onMessageReceived: (type, contents) => {
            console.log("Received message type:", type, "contents:", contents)

            if (type === 101) {  // ARTICLES_RESPONSE
                try {
                    articlesData = JSON.parse(contents)
                    console.log("Successfully parsed articles data:", articlesData.articles.length, "articles")
                } catch (e) {
                    console.log("Error parsing JSON:", e)
                }
            } else if (type === 102) {  // MARK_READ_RESPONSE
                try {
                    var response = JSON.parse(contents)
                    console.log("Mark as read response:", response)
                    if (response.success) {
                        loadArticles()
                    }
                } catch (e) {
                    console.log("Error parsing mark read response:", e)
                }
            } else if (type === 103) {  // ARTICLE_CONTENT_RESPONSE
                try {
                    var response = JSON.parse(contents)
                    console.log("Article content response:", response)
                    if (response.success) {
                        currentArticle = response.article
                        articleView.article = currentArticle
                        showingArticle = true
                    }
                } catch (e) {
                    console.log("Error parsing article content response:", e)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#ffffff"  // White background like ArticleView
        visible: !showingArticle

        // Header - exact same style as ArticleView
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 100 * scaleFactor
            color: "#f5f5f5"
            border.color: "#e0e0e0"
            border.width: 1

            // Left side - Title
            Image {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20 * scaleFactor
                width: 60 * scaleFactor  // Adjust this to fit your logo nicely
                height: 60 * scaleFactor  // Adjust this to fit your logo nicely
                source: "qrc:/ui/logo.svg"
                fillMode: Image.PreserveAspectFit
            }

            // Centre - Page indicator
            Row {
                anchors.centerIn: parent
                spacing: 8 * scaleFactor

                Text {
                    text: articlesData ? `Page ${swipeView.currentIndex + 1} of ${Math.ceil(articlesData.articles.length / articlesPerPage)}` : "Page 0 of 0"
                    font.pointSize: 12 * scaleFactor
                    color: "#666666"
                    anchors.verticalCenter: parent.verticalCenter
                }

                PageIndicator {
                    count: articlesData ? Math.ceil(articlesData.articles.length / articlesPerPage) : 0
                    currentIndex: swipeView.currentIndex
                    anchors.verticalCenter: parent.verticalCenter

                    delegate: Rectangle {
                        width: 12 * scaleFactor
                        height: 12 * scaleFactor
                        radius: 6 * scaleFactor
                        color: index === swipeView.currentIndex ? "black" : "lightgray"
                    }
                }
            }

            // Right side - Buttons
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 20 * scaleFactor
                spacing: 5 * scaleFactor

                Button {
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
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><polyline points='23,4 23,10 17,10'/><polyline points='1,20 1,14 7,14'/><path d='M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15'/></svg>"
                    }

                    onClicked: loadArticles()
                }

                Button {
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
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23333' stroke-width='2'><line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/></svg>"
                    }

                    onClicked: endpoint.terminate()  // Call terminate here as per docs
                }
            }
        }

        // Article list content
        SwipeView {
            id: swipeView
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 40 * scaleFactor
            clip: true

            Repeater {
                model: articlesData ? Math.ceil(articlesData.articles.length / articlesPerPage) : 0

                // Each page
                Column {
                    width: swipeView.width
                    spacing: 15 * scaleFactor

                    Repeater {
                        model: {
                            if (!articlesData) return []

                            var startIndex = index * articlesPerPage
                            var endIndex = Math.min(startIndex + articlesPerPage, articlesData.articles.length)
                            var pageArticles = []

                            for (var i = startIndex; i < endIndex; i++) {
                                pageArticles.push(articlesData.articles[i])
                            }

                            return pageArticles
                        }

                        // Replace the Rectangle item in the inner Repeater (the article card) with this:

                        Rectangle {
                            width: parent.width
                            height: 200 * scaleFactor
                            color: "white"
                            border.width: 1
                            border.color: "#ddd"
                            clip: true  // Important: prevents overflow

                            MouseArea {
                                anchors.fill: parent
                                onClicked: openArticle(modelData.id)
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 20 * scaleFactor
                                spacing: 20 * scaleFactor

                                // Thumbnail - Fixed width
                                Rectangle {
                                    id: thumbnailContainer
                                    width: 200 * scaleFactor
                                    height: 160 * scaleFactor
                                    color: "#f5f5f5"
                                    border.width: 1
                                    border.color: "#ddd"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: (modelData.thumbnail && modelData.thumbnail.src) ? modelData.thumbnail.src : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.thumbnail && modelData.thumbnail.src && modelData.thumbnail.src !== ""

                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                visible = false
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "No Image"
                                        font.family: bookerlyRegular.name
                                        font.pointSize: 12 * scaleFactor
                                        color: "#999"
                                        visible: !modelData.thumbnail || !modelData.thumbnail.src || modelData.thumbnail.src === ""
                                    }
                                }

                                // Article content - Use Item with anchors for better control
                                Item {
                                    width: parent.width - thumbnailContainer.width - parent.spacing
                                    height: parent.height

                                    // Title at top
                                    Text {
                                        id: titleText
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        text: modelData.title
                                        font.pointSize: 18 * scaleFactor
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    // Author/reading time below title
                                    Text {
                                        id: authorText
                                        anchors.top: titleText.bottom
                                        anchors.topMargin: 10 * scaleFactor
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        text: "By " + modelData.author + " • " + (modelData.reading_time || 0) + " min read"
                                        font.pointSize: 12 * scaleFactor
                                        color: "#666"
                                    }

                                    // Summary in the middle (takes remaining space)
                                    Text {
                                        id: summaryText
                                        anchors.top: authorText.bottom
                                        anchors.topMargin: 10 * scaleFactor
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: bottomRow.top
                                        anchors.bottomMargin: 10 * scaleFactor
                                        text: modelData.summary
                                        font.family: bookerlyRegular.name
                                        font.pointSize: 14 * scaleFactor
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        clip: true
                                    }

                                    // Bottom row with button and tags
                                    Item {
                                        id: bottomRow
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 40 * scaleFactor

                                        Button {
                                            id: markReadBtn
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Mark Read"
                                            font.pointSize: 12 * scaleFactor
                                            width: 120 * scaleFactor
                                            height: parent.height
                                            
                                            // Prevent button from interfering with card click
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    markAsRead(modelData.id)
                                                    mouse.accepted = true
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.left: markReadBtn.right
                                            anchors.leftMargin: 15 * scaleFactor
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.tags.join(", ")
                                            font.family: bookerlyRegular.name
                                            font.pointSize: 10 * scaleFactor
                                            color: "#007acc"
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ArticleView {
        id: articleView
        anchors.fill: parent
        scaleFactor: parent.scaleFactor
        visible: showingArticle

        onBackClicked: {
            showingArticle = false
        }

        onMarkAsReadClicked: (articleId) => {
            markAsRead(articleId)
        }
    }

    function loadArticles() {
        console.log("Requesting articles from backend...")
        endpoint.sendMessage(1, "GET_ARTICLES")
    }

    function markAsRead(articleId) {
        console.log("Marking article as read:", articleId)
        endpoint.sendMessage(2, articleId)
    }

    function openArticle(articleId) {
        console.log("Opening article:", articleId)
        endpoint.sendMessage(3, articleId)
    }

    Component.onCompleted: {
        loadArticles()
    }
}

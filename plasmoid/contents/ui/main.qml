import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── State ─────────────────────────────────────────────────────────────
    property var    posts:        []
    property int    currentIndex: -1
    property string currentTitle: ""
    property string currentMeta:  ""
    property bool   isAnimating:  false

    // ── Config helpers ────────────────────────────────────────────────────
    property var subredditList: {
        var raw = Plasmoid.configuration.subreddits || "showerthoughts"
        return raw.split(",")
            .map(function(s) { return s.trim().toLowerCase().replace(/^r\//, "") })
            .filter(function(s) { return s.length > 0 })
    }

    // ── Fetching ──────────────────────────────────────────────────────────
    function fetchAllPosts() {
        root.posts        = []
        root.currentIndex = -1
        subredditList.forEach(fetchSubreddit)
    }

    function fetchSubreddit(sub) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://www.reddit.com/r/" + sub + "/top.json?limit=50&t=week", true)
        xhr.setRequestHeader("User-Agent", "Plasma/ShowerthoughtsWidget 1.0")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.log("ShowerthoughtsWidget: HTTP " + xhr.status + " for r/" + sub)
                return
            }
            try {
                var data     = JSON.parse(xhr.responseText)
                var newPosts = data.data.children
                    .filter(function(c) {
                        return !c.data.stickied && c.data.title && c.data.title.length > 15
                    })
                    .map(function(c) {
                        return {
                            title:     c.data.title,
                            author:    c.data.author,
                            subreddit: c.data.subreddit_name_prefixed || ("r/" + sub)
                        }
                    })

                var combined = root.posts.concat(newPosts)
                // Fisher-Yates shuffle so posts from multiple subreddits mix evenly
                for (var i = combined.length - 1; i > 0; i--) {
                    var j    = Math.floor(Math.random() * (i + 1))
                    var tmp  = combined[i]
                    combined[i] = combined[j]
                    combined[j] = tmp
                }
                root.posts = combined

                if (root.currentIndex === -1 && root.posts.length > 0) {
                    root.currentIndex = 0
                    root.showCurrent()
                }
            } catch(e) {
                console.log("ShowerthoughtsWidget: Parse error for r/" + sub + ": " + e)
            }
        }
        xhr.send()
    }

    function showCurrent() {
        if (currentIndex < 0 || currentIndex >= posts.length) return
        var p        = posts[currentIndex]
        currentTitle = p.title
        currentMeta  = "u/" + p.author + "  ·  " + p.subreddit
    }

    function nextPost() {
        if (posts.length === 0 || isAnimating) return
        isAnimating = true
        fadeOut.start()
    }

    // ── Timers ────────────────────────────────────────────────────────────
    Timer {
        interval: (Plasmoid.configuration.refreshInterval || 300) * 1000
        running:  root.posts.length > 0
        repeat:   true
        onTriggered: root.nextPost()
    }

    Timer {
        interval: 3600000   // re-fetch from Reddit every hour
        running:  true
        repeat:   true
        onTriggered: root.fetchAllPosts()
    }

    Connections {
        target: Plasmoid.configuration
        function onSubredditsChanged() { root.fetchAllPosts() }
    }

    Component.onCompleted: fetchAllPosts()

    // ── UI ────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth:  520
        implicitHeight: 230

        Item {
            id: contentArea
            anchors.fill:    parent
            anchors.margins: 28
            opacity:         1.0

            // Decorative opening guillemet — large, ghosted
            Text {
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.topMargin:  -20
                anchors.leftMargin: -6
                text:               "“"
                font.family:        "Noto Serif, Georgia, serif"
                font.pixelSize:     88
                color:              "#ffffff"
                opacity:            0.15
                style:              Text.Raised
                styleColor:         "#99000000"
            }

            // ── Main thought ──────────────────────────────────────────────
            Text {
                id: mainText
                anchors {
                    top:          parent.top
                    left:         parent.left
                    right:        parent.right
                    bottom:       metaRow.top
                    topMargin:    6
                    bottomMargin: 14
                }
                text:              root.currentTitle.length > 0
                                       ? root.currentTitle
                                       : (root.posts.length === 0 ? "Fetching thoughts…" : "")
                wrapMode:          Text.WordWrap
                font.family:       "Noto Serif, Georgia, serif"
                font.pixelSize:    Plasmoid.configuration.fontSize || 20
                font.italic:       true
                lineHeight:        1.4
                color:             "#ffffff"
                verticalAlignment: Text.AlignVCenter
                style:             Text.Raised
                styleColor:        "#cc000000"
                fontSizeMode:      Text.Fit
                minimumPixelSize:  11
            }

            // ── Author / subreddit ────────────────────────────────────────
            Row {
                id:      metaRow
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                spacing: 10
                visible: Plasmoid.configuration.showMeta && root.currentMeta !== ""

                Rectangle {
                    width:   28
                    height:  1
                    color:   "#ffffff"
                    opacity: 0.30
                    anchors.verticalCenter: metaLabel.verticalCenter
                }

                Text {
                    id:              metaLabel
                    text:            root.currentMeta
                    font.family:     "Noto Sans, sans-serif"
                    font.pixelSize:  11
                    letterSpacing:   0.6
                    color:           "#ffffff"
                    opacity:         0.45
                    style:           Text.Raised
                    styleColor:      "#88000000"
                }
            }

            // ── Transitions ───────────────────────────────────────────────
            NumberAnimation {
                id:       fadeOut
                target:   contentArea
                property: "opacity"
                from:     1.0; to: 0.0
                duration: 380
                easing.type: Easing.InOutQuad
                onStopped: {
                    root.currentIndex = (root.currentIndex + 1) % Math.max(1, root.posts.length)
                    root.showCurrent()
                    fadeIn.start()
                }
            }

            NumberAnimation {
                id:       fadeIn
                target:   contentArea
                property: "opacity"
                from:     0.0; to: 1.0
                duration: 380
                easing.type: Easing.InOutQuad
                onStopped: { root.isAnimating = false }
            }
        }

        // Click anywhere to advance
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.nextPost()
        }
    }
}

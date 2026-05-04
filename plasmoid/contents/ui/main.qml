import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── State ──────────────────────────────────────────────────────────────
    property var    posts:        []
    property var    seenIds:      ({})
    property var    cursors:      ({})
    property string currentTitle: ""
    property string currentMeta:  ""
    property string currentUrl:   ""
    property bool   isAnimating:  false
    property double lastFetchMore: 0

    // Signal that crosses the fullRepresentation component boundary
    signal triggerNext()

    // ── Config helpers ─────────────────────────────────────────────────────
    property var subredditList: {
        var raw = Plasmoid.configuration.subreddits || "showerthoughts"
        return raw.split(",")
            .map(function(s) { return s.trim().toLowerCase().replace(/^r\//, "") })
            .filter(function(s) { return s.length > 0 })
    }

    // ── Fetching ───────────────────────────────────────────────────────────
    function fetchAllPosts() {
        root.posts         = []
        root.seenIds       = {}
        root.cursors       = {}
        root.lastFetchMore = 0
        subredditList.forEach(function(sub) { fetchSubreddit(sub, null) })
    }

    function fetchMore() {
        var now = Date.now()
        if (now - root.lastFetchMore < 60000) return
        root.lastFetchMore = now
        subredditList.forEach(function(sub) {
            if (root.cursors[sub]) fetchSubreddit(sub, root.cursors[sub])
        })
    }

    function fetchSubreddit(sub, after) {
        var url = "https://www.reddit.com/r/" + sub + "/top.json?limit=100&t=all"
        if (after) url += "&after=" + encodeURIComponent(after)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, true)
        xhr.setRequestHeader("User-Agent", "Plasma/ShowerthoughtsWidget 1.0")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.log("ShowerthoughtsWidget: HTTP " + xhr.status + " for r/" + sub)
                return
            }
            try {
                var listing  = JSON.parse(xhr.responseText).data
                root.cursors[sub] = listing.after || null

                var newPosts = listing.children
                    .filter(function(c) {
                        return !c.data.stickied && c.data.title && c.data.title.length > 15
                    })
                    .map(function(c) {
                        return {
                            id:        c.data.id,
                            title:     c.data.title,
                            author:    c.data.author,
                            subreddit: c.data.subreddit_name_prefixed || ("r/" + sub),
                            year:      new Date(c.data.created_utc * 1000).getFullYear(),
                            url:       "https://www.reddit.com/r/" + sub + "/comments/" + c.data.id + "/"
                        }
                    })

                root.posts = root.posts.concat(newPosts)

                if (root.currentTitle === "" && root.posts.length > 0) root.advance()
            } catch(e) {
                console.log("ShowerthoughtsWidget: Parse error for r/" + sub + ": " + e)
            }
        }
        xhr.send()
    }

    // ── Navigation ─────────────────────────────────────────────────────────
    function advance() {
        var pool = root.posts.filter(function(p) { return !root.seenIds[p.id] })
        if (pool.length < 15) root.fetchMore()
        if (pool.length === 0) { root.seenIds = {}; pool = root.posts }

        var pick          = pool[Math.floor(Math.random() * pool.length)]
        root.seenIds[pick.id] = true
        root.currentTitle = pick.title
        root.currentUrl   = pick.url
        root.currentMeta  = "u/" + pick.author + "  ·  " + pick.subreddit + "  ·  " + pick.year
    }

    function nextPost() {
        if (root.isAnimating || root.posts.length === 0) return
        root.isAnimating = true
        root.triggerNext()   // caught by Connections inside fullRepresentation
    }

    // ── Timers ─────────────────────────────────────────────────────────────
    Timer {
        interval: (Plasmoid.configuration.refreshInterval || 300) * 1000
        running:  root.currentTitle !== ""
        repeat:   true
        onTriggered: root.nextPost()
    }

    Connections {
        target: Plasmoid.configuration
        function onSubredditsChanged() { root.fetchAllPosts() }
    }

    Component.onCompleted: fetchAllPosts()

    // ── UI ─────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth:  520
        implicitHeight: 230

        // Receive the signal and run the animation — transition is in scope here
        Connections {
            target: root
            function onTriggerNext() { transition.start() }
        }

        Item {
            id: contentArea
            anchors.fill:    parent
            anchors.margins: 28
            opacity:         1.0

            Text {
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.topMargin:  -20
                anchors.leftMargin: -6
                text:               "“"
                font.family:        Plasmoid.configuration.fontFamily || "Noto Serif"
                font.pixelSize:     88
                color:              "#ffffff"
                opacity:            0.15
                style:              Text.Raised
                styleColor:         "#99000000"
            }

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
                text:              root.currentTitle.length > 0 ? root.currentTitle : "Fetching thoughts…"
                wrapMode:          Text.WordWrap
                font.family:       Plasmoid.configuration.fontFamily || "Noto Serif"
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
                    id:             metaLabel
                    text:           root.currentMeta
                    font.family:    "Noto Sans, sans-serif"
                    font.pixelSize: 11
                    color:          "#ffffff"
                    opacity:        0.45
                    style:          Text.Raised
                    styleColor:     "#88000000"
                }
            }
        }

        SequentialAnimation {
            id: transition
            NumberAnimation {
                target:      contentArea
                property:    "opacity"
                to:          0.0
                duration:    350
                easing.type: Easing.InOutQuad
            }
            ScriptAction  { script: root.advance() }
            NumberAnimation {
                target:      contentArea
                property:    "opacity"
                to:          1.0
                duration:    350
                easing.type: Easing.InOutQuad
            }
            onStopped: root.isAnimating = false
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor

            onClicked:       clickTimer.restart()
            onDoubleClicked: { clickTimer.stop(); if (root.currentUrl !== "") Qt.openUrlExternally(root.currentUrl) }

            Timer {
                id:       clickTimer
                interval: 220
                onTriggered: root.nextPost()
            }
        }
    }
}

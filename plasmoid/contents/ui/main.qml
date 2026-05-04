import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── State ──────────────────────────────────────────────────────────────
    property var    posts:        []    // all fetched posts
    property var    seenIds:      ({})  // {id: true} — never repeat within session
    property var    cursors:      ({})  // {subreddit: afterCursor} for pagination
    property string currentTitle: ""
    property string currentMeta:  ""
    property bool   isAnimating:  false
    property double lastFetchMore: 0   // throttle background pagination

    // ── Config helpers ─────────────────────────────────────────────────────
    property var subredditList: {
        var raw = Plasmoid.configuration.subreddits || "showerthoughts"
        return raw.split(",")
            .map(function(s) { return s.trim().toLowerCase().replace(/^r\//, "") })
            .filter(function(s) { return s.length > 0 })
    }

    // ── Fetching ───────────────────────────────────────────────────────────
    function fetchAllPosts() {
        root.posts    = []
        root.seenIds  = {}
        root.cursors  = {}
        root.lastFetchMore = 0
        subredditList.forEach(function(sub) { fetchSubreddit(sub, null) })
    }

    function fetchMore() {
        var now = Date.now()
        if (now - root.lastFetchMore < 60000) return  // once per minute max
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
                var listing = JSON.parse(xhr.responseText).data

                // Save pagination cursor for next call
                root.cursors[sub] = listing.after || null

                var newPosts = listing.children
                    .filter(function(c) {
                        return !c.data.stickied
                            && c.data.title
                            && c.data.title.length > 15
                    })
                    .map(function(c) {
                        return {
                            id:        c.data.id,
                            title:     c.data.title,
                            author:    c.data.author,
                            subreddit: c.data.subreddit_name_prefixed || ("r/" + sub),
                            year:      new Date(c.data.created_utc * 1000).getFullYear()
                        }
                    })

                root.posts = root.posts.concat(newPosts)

                if (root.currentTitle === "" && root.posts.length > 0) {
                    root.advance()
                }
            } catch(e) {
                console.log("ShowerthoughtsWidget: Parse error for r/" + sub + ": " + e)
            }
        }
        xhr.send()
    }

    // ── Navigation ─────────────────────────────────────────────────────────
    function advance() {
        var pool = root.posts.filter(function(p) { return !root.seenIds[p.id] })

        // Running low — quietly fetch the next page in the background
        if (pool.length < 15) root.fetchMore()

        // Fully exhausted — reset seen set and start over
        if (pool.length === 0) {
            root.seenIds = {}
            pool = root.posts
        }

        var pick = pool[Math.floor(Math.random() * pool.length)]
        root.seenIds[pick.id] = true
        root.currentTitle     = pick.title
        root.currentMeta      = "u/" + pick.author
                                + "  ·  " + pick.subreddit
                                + "  ·  " + pick.year
    }

    function nextPost() {
        if (root.isAnimating || root.posts.length === 0) return
        root.isAnimating = true
        fadeOut.start()
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

        Item {
            id: contentArea
            anchors.fill:    parent
            anchors.margins: 28
            opacity:         1.0

            // Decorative opening quote — ghosted, top-left
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

            // ── Main thought ───────────────────────────────────────────────
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
                                       : "Fetching thoughts…"
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

            // ── Author · Subreddit · Year ──────────────────────────────────
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
                    letterSpacing:  0.6
                    color:          "#ffffff"
                    opacity:        0.45
                    style:          Text.Raised
                    styleColor:     "#88000000"
                }
            }

            // ── Transitions ────────────────────────────────────────────────
            NumberAnimation {
                id:       fadeOut
                target:   contentArea
                property: "opacity"
                from:     1.0; to: 0.0
                duration: 380
                easing.type: Easing.InOutQuad
                onStopped: {
                    root.advance()
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

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.nextPost()
        }
    }
}

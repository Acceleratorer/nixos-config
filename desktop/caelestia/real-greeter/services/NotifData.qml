pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    property bool closed
    property date time: new Date()
    property string timeStr: qsTr("now")
    property string summary
    property string body
    property string appIcon
    property string appName
    property string image
    property int urgency

    function lock(item: Item): void {
    }

    function unlock(item: Item): void {
    }
}

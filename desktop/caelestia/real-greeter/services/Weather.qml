pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string description: qsTr("Weather unavailable")
    readonly property string icon: "cloud_off"
    readonly property string temp: "--°C"
    readonly property list<var> forecast: []
    readonly property list<var> hourlyForecast: []

    function formatTemp(temp: var): string {
        return "--°C";
    }

    function reload(): void {
    }
}

import QtQuick
import org.kde.notification

// Fires native desktop notifications for due reminders. Each fire spawns a fresh,
// self-deleting Notification so simultaneous reminders don't overwrite each other.
// Falls back to notify-send (via the injected runCommand) if the component can't
// be created.
Item {
    id: n

    // injected by main.qml: function(cmd) that runs a shell command
    property var runCommand: null

    function urgencyEnum(s) {
        switch (s) {
        case "low":      return Notification.LowUrgency;
        case "critical": return Notification.CriticalUrgency;
        default:         return Notification.NormalUrgency;
        }
    }
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'"; }

    Component {
        id: notifComp
        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "com.conqrex.memokeel"
            autoDelete: true
        }
    }

    function fire(title, text, urgency) {
        if (notifComp.status === Component.Ready) {
            var o = notifComp.createObject(n, {
                title: title, text: text, urgency: urgencyEnum(urgency)
            });
            if (o) { o.sendEvent(); return; }
        }
        if (runCommand) runCommand("notify-send -a " + shq("MemoKeel") + " " + shq(title) + " " + shq(text));
    }
}

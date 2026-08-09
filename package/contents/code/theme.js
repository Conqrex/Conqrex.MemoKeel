.pragma library

// Neon preset palette, matching the Conqrex gauge widget's accents. Colors are
// hex strings (no Qt/Kirigami dependency in this library); the QML caller passes
// a fallback for the empty/"default" key so it can resolve to the theme highlight.

var PALETTE = {
    cyan:   "#34d3eb",
    sky:    "#38bdf8",
    violet: "#9476fa",
    lime:   "#94db38",
    amber:  "#fabb29",
    rose:   "#fa7085",
    slate:  "#94a3c7"
};

// the order shown in the color picker (empty string = "default / theme highlight")
var ORDER = ["", "cyan", "sky", "violet", "lime", "amber", "rose", "slate"];

var LABELS = {
    "":     "Default",
    cyan:   "Cyan",
    sky:    "Sky",
    violet: "Violet",
    lime:   "Lime",
    amber:  "Amber",
    rose:   "Rose",
    slate:  "Slate"
};

function accentFor(key, fallback) {
    if (key && PALETTE[key]) return PALETTE[key];
    return fallback || PALETTE.cyan;
}

function label(key) { return LABELS[key] !== undefined ? LABELS[key] : key; }

// priority 0..4 -> a neon color key ("" = none)
function priorityKey(p) {
    switch (p) {
    case 4: return "rose";    // urgent
    case 3: return "amber";   // high
    case 2: return "sky";     // medium
    case 1: return "slate";   // low
    default: return "";
    }
}
function priorityColor(p, fallback) {
    var k = priorityKey(p);
    return k ? PALETTE[k] : (fallback || "transparent");
}

// status -> color key for kanban / todo chips
function statusColor(status) {
    switch (status) {
    case "done":  return PALETTE.lime;
    case "doing": return PALETTE.amber;
    default:      return PALETTE.slate;
    }
}

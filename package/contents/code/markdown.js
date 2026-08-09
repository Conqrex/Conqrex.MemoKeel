.pragma library

// A small, safe Markdown -> Text.RichText (HTML) converter. The input is ALWAYS
// HTML-escaped before any markup is produced, so note bodies can never inject
// arbitrary RichText/HTML. Supports headings, bold/italic/code, fenced code,
// lists, ordered lists, blockquotes, hr, links, [[wiki-links]] and inline
// checklists ("- [ ]" / "- [x]").

function escapeHtml(s) {
    return ("" + (s || ""))
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

// inline markup on already-escaped text
function inline(s) {
    s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
    s = s.replace(/__([^_]+)__/g, '<b>$1</b>');
    s = s.replace(/(^|[^\*])\*([^*\s][^*]*)\*/g, '$1<i>$2</i>');
    s = s.replace(/(^|[^_])_([^_\s][^_]*)_/g, '$1<i>$2</i>');
    // wiki links first (so they aren't eaten by the markdown-link rule)
    s = s.replace(/\[\[([^\]]+)\]\]/g,
        '<a href="qn-wiki:$1" style="color:#34d3eb;text-decoration:none;">$1</a>');
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    return s;
}

function toRichText(md) {
    var lines = ("" + (md || "")).split(/\r?\n/);
    var html = "", inCode = false, inUl = false, inOl = false;
    function closeLists() {
        if (inUl) { html += "</ul>"; inUl = false; }
        if (inOl) { html += "</ol>"; inOl = false; }
    }
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];

        if (/^\s*```/.test(line)) {
            if (inCode) { html += "</pre>"; inCode = false; }
            else { closeLists(); html += '<pre style="background:#1e293b;padding:4px;">'; inCode = true; }
            continue;
        }
        if (inCode) { html += escapeHtml(line) + "\n"; continue; }

        // checklist item
        var cl = line.match(/^\s*[-*]\s+\[([ xX])\]\s+(.*)$/);
        if (cl) {
            closeLists();
            var checked = cl[1].toLowerCase() === "x";
            var box = checked ? '<span style="color:#94db38;">&#10003;</span>'
                              : '<span style="color:#94a3c7;">&#9744;</span>';
            var body = inline(escapeHtml(cl[2]));
            var style = checked ? ' style="color:#7c8aa5;"' : '';
            html += '<div' + style + '>' + box + ' ' + body + '</div>';
            continue;
        }

        var h = line.match(/^(#{1,6})\s+(.*)$/);
        if (h) {
            closeLists();
            var lvl = Math.min(6, h[1].length + 1);
            html += '<h' + lvl + '>' + inline(escapeHtml(h[2])) + '</h' + lvl + '>';
            continue;
        }

        if (/^\s*(---|\*\*\*|___)\s*$/.test(line)) { closeLists(); html += '<hr/>'; continue; }

        var bq = line.match(/^\s*>\s?(.*)$/);
        if (bq) {
            closeLists();
            html += '<blockquote style="color:#9aa7c7;border-left:2px solid #34d3eb;padding-left:6px;">'
                  + inline(escapeHtml(bq[1])) + '</blockquote>';
            continue;
        }

        var ul = line.match(/^\s*[-*]\s+(.*)$/);
        if (ul) {
            if (inOl) { html += "</ol>"; inOl = false; }
            if (!inUl) { html += "<ul>"; inUl = true; }
            html += '<li>' + inline(escapeHtml(ul[1])) + '</li>';
            continue;
        }

        var ol = line.match(/^\s*\d+\.\s+(.*)$/);
        if (ol) {
            if (inUl) { html += "</ul>"; inUl = false; }
            if (!inOl) { html += "<ol>"; inOl = true; }
            html += '<li>' + inline(escapeHtml(ol[1])) + '</li>';
            continue;
        }

        if (/^\s*$/.test(line)) { closeLists(); html += '<br/>'; continue; }

        closeLists();
        html += '<div>' + inline(escapeHtml(line)) + '</div>';
    }
    if (inCode) html += "</pre>";
    closeLists();
    return html;
}

// distinct [[Title]] references in order of first appearance
function extractWikiLinks(md) {
    var out = [], seen = {}, re = /\[\[([^\]]+)\]\]/g, m;
    while ((m = re.exec(md || "")) !== null) {
        var t = m[1].trim(), k = t.toLowerCase();
        if (t && !seen[k]) { seen[k] = true; out.push(t); }
    }
    return out;
}

function checklistProgress(md) {
    var lines = ("" + (md || "")).split(/\r?\n/), done = 0, total = 0;
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*[-*]\s+\[([ xX])\]/);
        if (m) { total++; if (m[1].toLowerCase() === "x") done++; }
    }
    return { done: done, total: total };
}

// toggle the nth checklist checkbox (0-based) and return the new body
function toggleChecklistAt(md, nth) {
    var lines = ("" + (md || "")).split(/\r?\n/), idx = -1;
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^(\s*[-*]\s+\[)([ xX])(\].*)$/);
        if (m) {
            idx++;
            if (idx === nth) {
                var checked = m[2].toLowerCase() === "x";
                lines[i] = m[1] + (checked ? " " : "x") + m[3];
                break;
            }
        }
    }
    return lines.join("\n");
}

// strip markup for compact one-line previews
function plainPreview(md, max) {
    var s = ("" + (md || ""))
        .replace(/```[\s\S]*?```/g, " ")
        .replace(/`{1,3}/g, "")
        .replace(/^\s*[-*]\s+\[[ xX]\]\s+/gm, "")
        .replace(/[*_#>]/g, "")
        .replace(/\[\[([^\]]+)\]\]/g, "$1")
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
        .replace(/\r?\n+/g, "  ")
        .trim();
    if (max && s.length > max) s = s.substring(0, max) + "…";
    return s;
}

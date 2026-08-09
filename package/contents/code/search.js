.pragma library

// Fuzzy subsequence search + tag filtering + wiki-link/backlink index.

function norm(s) { return ("" + (s || "")).toLowerCase(); }

function tokenize(s) {
    return norm(s).split(/[^a-z0-9]+/).filter(function (t) { return t.length > 0; });
}

// Subsequence fuzzy score: >= 0 when every query char occurs in order, else -1.
// Consecutive matches and an early/word-start match score higher.
function fuzzyScore(query, text) {
    query = norm(query); text = norm(text);
    if (!query) return 0;
    if (!text) return -1;
    var qi = 0, score = 0, streak = 0, lastIdx = -2;
    for (var ti = 0; ti < text.length && qi < query.length; ti++) {
        if (text.charAt(ti) === query.charAt(qi)) {
            streak = (lastIdx === ti - 1) ? streak + 1 : 1;
            score += streak;
            if (ti === 0 || /[^a-z0-9]/.test(text.charAt(ti - 1))) score += 2; // word start
            lastIdx = ti;
            qi++;
        }
    }
    return qi === query.length ? score : -1;
}

function tagNames(item, tagsMap) {
    var out = [], ids = item.tagIds || [];
    for (var i = 0; i < ids.length; i++) {
        var t = (tagsMap || {})[ids[i]];
        if (t) out.push(t.name);
    }
    return out;
}

// Best fuzzy score of a query across an item's text fields + tag names. -1 = no match.
function matchScore(query, item, tagsMap) {
    if (!query) return 0;
    var fields = [item.title, item.text, item.body].concat(tagNames(item, tagsMap));
    var best = -1;
    for (var i = 0; i < fields.length; i++) {
        var s = fuzzyScore(query, fields[i] || "");
        if (s > best) best = s;
    }
    return best;
}

function matches(query, item, tagsMap) { return matchScore(query, item, tagsMap) >= 0; }

function hasTag(item, tagId) {
    if (!tagId) return true;
    return (item.tagIds || []).indexOf(tagId) >= 0;
}

// Resolve [[Title]] references across notes into forward links + backlinks.
//   linksFrom[noteId] = [{title, id|null}]
//   backlinks[noteId] = [sourceNoteId, ...]
function buildLinkIndex(notes) {
    var byTitle = {};
    for (var i = 0; i < notes.length; i++) {
        var n = notes[i];
        if (n.title) byTitle[norm(n.title)] = n.id;
    }
    var linksFrom = {}, backlinks = {};
    var re = /\[\[([^\]]+)\]\]/g;
    for (var j = 0; j < notes.length; j++) {
        var note = notes[j], body = note.body || "", m, seen = {};
        linksFrom[note.id] = [];
        re.lastIndex = 0;
        while ((m = re.exec(body)) !== null) {
            var title = m[1].trim(), key = norm(title);
            if (!title || seen[key]) continue;
            seen[key] = true;
            var targetId = byTitle[key] || null;
            linksFrom[note.id].push({ title: title, id: targetId });
            if (targetId) {
                if (!backlinks[targetId]) backlinks[targetId] = [];
                if (backlinks[targetId].indexOf(note.id) < 0) backlinks[targetId].push(note.id);
            }
        }
    }
    return { linksFrom: linksFrom, backlinks: backlinks, byTitle: byTitle };
}

// Rank items by fuzzy score (descending), dropping non-matches.
function rank(query, items, tagsMap) {
    var scored = [];
    for (var i = 0; i < items.length; i++) {
        var s = matchScore(query, items[i], tagsMap);
        if (s >= 0) scored.push({ item: items[i], score: s });
    }
    scored.sort(function (a, b) { return b.score - a.score; });
    return scored.map(function (e) { return e.item; });
}

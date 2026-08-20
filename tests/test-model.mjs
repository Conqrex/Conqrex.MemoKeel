import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

function qmlJs(path) {
    return fs.readFileSync(path, "utf8")
        .replace(/^\.pragma library\s*$/gm, "")
        .replace(/^\.import .*$/gm, "");
}

const schemaContext = vm.createContext({});
vm.runInContext(qmlJs("package/contents/code/schema.js"), schemaContext);
const Schema = {
    defaultDoc: schemaContext.defaultDoc,
    makeNote: schemaContext.makeNote,
    makeTodo: schemaContext.makeTodo,
    makeBoard: schemaContext.makeBoard,
    makeColumn: schemaContext.makeColumn,
    makeCard: schemaContext.makeCard,
    makeReminder: schemaContext.makeReminder,
    makeTag: schemaContext.makeTag
};
const modelContext = vm.createContext({ Schema });
vm.runInContext(qmlJs("package/contents/code/model.js"), modelContext);

let doc = Schema.defaultDoc();
let result = modelContext.addBoard(doc, { title: "CrewBeacon" });
doc = result.doc;
const boardA = result.id;
result = modelContext.addColumn(doc, boardA, { title: "To Do" });
doc = result.doc;
const colA = result.id;
result = modelContext.addCard(doc, colA, { title: "Fix quota" });
doc = result.doc;
const cardA = result.id;

result = modelContext.addBoard(doc, { title: "MemoKeel" });
doc = result.doc;
const boardB = result.id;
result = modelContext.addColumn(doc, boardB, { title: "Backlog" });
doc = result.doc;
const colB1 = result.id;
result = modelContext.addColumn(doc, boardB, { title: "Done" });
doc = result.doc;
const colB2 = result.id;
result = modelContext.addCard(doc, colB1, { title: "Board tabs" });
doc = result.doc;
const cardB = result.id;

assert.deepEqual(Array.from(modelContext.columnsOf(doc, boardA), c => c.id), [colA]);
assert.deepEqual(Array.from(modelContext.columnsOf(doc, boardB), c => c.id), [colB1, colB2]);
assert.equal(modelContext.cardsOf(doc, colA)[0].id, cardA);
assert.equal(modelContext.cardsOf(doc, colB1)[0].id, cardB);

doc = modelContext.moveCardBefore(doc, cardB, colB2, null);
assert.equal(doc.cards.find(c => c.id === cardB).columnId, colB2);
assert.equal(modelContext.cardsOf(doc, colB1).length, 0);
assert.equal(modelContext.cardsOf(doc, colB2)[0].id, cardB);

result = modelContext.addBoard(doc, { title: "Empty project" });
doc = result.doc;
const boardC = result.id;
doc = modelContext.moveCardToBoard(doc, cardB, boardC, "To Do");
const boardCColumns = Array.from(modelContext.columnsOf(doc, boardC));
assert.equal(boardCColumns.length, 1);
assert.equal(boardCColumns[0].title, "To Do");
assert.equal(doc.cards.find(c => c.id === cardB).columnId, boardCColumns[0].id);

doc = modelContext.softDelete(doc, "boards", boardA, 14);
assert.equal(doc.boards.some(b => b.id === boardA), false);
assert.equal(doc.columns.some(c => c.id === colA), false);
assert.equal(doc.cards.some(c => c.id === cardA), false);
assert.equal(doc.boards.some(b => b.id === boardB), true);
assert.equal(doc.columns.some(c => c.id === colB2), true);
assert.equal(doc.cards.some(c => c.id === cardB), true);

console.log("multi-board model tests: PASS");

// Exercise the real QML JavaScript functions without starting a phone compositor.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const functions = source.slice(source.indexOf('    function load('), source.lastIndexOf('}'));
assert.ok(functions.startsWith('    function load('));
const Mir = Object.fromEntries(['Restored', 'Maximized', 'Fullscreen', 'Minimized', 'Hidden', 'Unknown']
    .map((name, index) => [`${name}State`, index]));
let saved, row;
const context = vm.createContext({
    Mir, loadedState: undefined,
    Qt: {rect: (...args) => args}, units: {gu: value => value},
    target: {appId: 'test-app', windowedX: 0, windowedY: 0},
    WindowStateStorage: {
        getGeometry: (id, fallback) => ({x: fallback[0], y: fallback[1], width: fallback[2], height: fallback[3]}),
        getState: () => row,
        saveState: (id, state) => { assert.equal(id, 'test-app'); saved = state; },
        saveGeometry: () => {},
    },
});
vm.runInContext(functions, context);
const transient = [Mir.MinimizedState, Mir.HiddenState, Mir.UnknownState];
for (const state of Object.values(Mir)) {
    row = state;
    vm.runInContext('load(false)', context);
    assert.equal(context.loadedState, transient.includes(state) ? Mir.RestoredState : state);
    for (const previous of Object.values(Mir)) {
        context.target.windowState = state;
        context.target.prevWindowState = previous;
        vm.runInContext('save()', context);
        const expected = transient.includes(state)
            ? (transient.includes(previous) ? Mir.RestoredState : previous) : state;
        assert.equal(saved, expected);
    }
}
console.log('WindowStateSaver: valid states preserved; transient load/save states repaired.');

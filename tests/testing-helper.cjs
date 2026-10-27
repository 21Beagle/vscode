const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const callbacks = new Map();
const calls = [];
let selection = { include: ['controller\0suite\0focused-test'], exclude: [] };
const vscode = { commands: {
    registerCommand(id, callback) { callbacks.set(id, callback); return { dispose() {} }; },
    async executeCommand(...args) {
        calls.push(args);
        if (args[0] === '_testing.getExplorerSelection') return selection;
    },
} };
const sandbox = { exports: {}, require(name) { assert.equal(name, 'vscode'); return vscode; }, setTimeout, clearTimeout };
const helper = path.join(__dirname, '../extensions/scm-keybindings/extension.cjs');
vm.runInNewContext(fs.readFileSync(helper, 'utf8'), sandbox);
sandbox.exports.activate({ subscriptions: [] });
(async () => {
    for (const [id, group] of [['beagle.testing.runFocused', 2], ['beagle.testing.debugFocused', 4]]) {
        calls.length = 0;
        await callbacks.get(id)();
        assert.deepEqual(calls, [
            ['list.selectAndPreserveFocus'],
            ['_testing.getExplorerSelection'],
            ['vscode.runTestsById', group, 'controller\0suite\0focused-test'],
        ]);
    }
    for (selection of [undefined, { include: [], exclude: [] }]) {
        calls.length = 0;
        await callbacks.get('beagle.testing.runFocused')();
        assert.equal(calls.length, 2, 'An empty selection must never fall back to Run All');
    }
    assert(callbacks.has('beagle.debug.watchClipboard'));
    assert(callbacks.has('beagle.scm.openFile'));
    assert(callbacks.has('beagle.terminal.escape'));
    console.log('Passed: focused-test run/debug IDs, selection ordering, empty selection, existing helper commands.');
})().catch(error => { console.error(error); process.exitCode = 1; });

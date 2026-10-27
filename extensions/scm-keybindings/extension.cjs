const vscode = require('vscode');

function fileFromTab(tab) {
    const input = tab?.input;
    if (input instanceof vscode.TabInputTextDiff) {
        return input.modified.scheme === 'git' ? vscode.Uri.file(input.modified.fsPath) : input.modified;
    }
    if (input instanceof vscode.TabInputText) return input.uri;
}

function activate(context) {
    for (const [direction, regular, diff] of [
        ['next', 'workbench.action.editor.nextChange', 'workbench.action.compareEditor.nextChange'],
        ['previous', 'workbench.action.editor.previousChange', 'workbench.action.compareEditor.previousChange'],
    ]) {
        context.subscriptions.push(vscode.commands.registerCommand(`beagle.navigation.${direction}Change`, async () => {
            const tab = vscode.window.tabGroups.activeTabGroup.activeTab;
            const isDiff = tab?.input instanceof vscode.TabInputTextDiff;
            await vscode.commands.executeCommand(isDiff ? diff : regular);
        }));
    }
    let opening = false;
    context.subscriptions.push(vscode.commands.registerCommand('beagle.scm.openFile', async () => {
        if (opening) return;
        opening = true;
        const initial = vscode.window.tabGroups.activeTabGroup.activeTab;
        const initialInput = initial?.input;
        let subscription, editorSubscription, timeout;
        let finish;
        const opened = new Promise(resolve => {
            finish = resolve;
            const check = () => {
                const tab = vscode.window.tabGroups.activeTabGroup.activeTab;
                if (tab !== initial || tab?.input !== initialInput) {
                    const uri = fileFromTab(tab);
                    if (uri) resolve(uri);
                }
            };
            subscription = vscode.window.tabGroups.onDidChangeTabs(check);
            editorSubscription = vscode.window.onDidChangeActiveTextEditor(check);
        });
        try {
            await vscode.commands.executeCommand('list.select');
            // Reopening the already-active diff produces no tab-change event.
            timeout = setTimeout(() => finish(fileFromTab(vscode.window.tabGroups.activeTabGroup.activeTab)), 1000);
            const uri = await opened;
            if (!uri) return;
            try {
                await vscode.workspace.fs.stat(uri);
            } catch {
                vscode.window.showInformationMessage('This file no longer exists. Use Enter to view its diff.');
                return;
            }
            await vscode.commands.executeCommand('vscode.open', uri, { preview: false, preserveFocus: false });
        } finally {
            clearTimeout(timeout);
            subscription?.dispose();
            editorSubscription?.dispose();
            opening = false;
        }
    }));
}

exports.activate = activate;

const activateBeforeTerminalEscape = exports.activate;
exports.activate = function (context) {
    activateBeforeTerminalEscape(context);
    let lastEscape = 0;
    let lastTerminal;
    context.subscriptions.push(vscode.commands.registerCommand('beagle.terminal.escape', async () => {
        const terminal = vscode.window.activeTerminal;
        if (!terminal) return;
        const now = Date.now();
        if (terminal === lastTerminal && lastEscape && now - lastEscape <= 500) {
            lastEscape = 0;
            lastTerminal = undefined;
            await vscode.commands.executeCommand('workbench.action.closeQuickOpen');
            if (vscode.window.tabGroups.activeTabGroup.tabs.length === 0) {
                await vscode.commands.executeCommand('workbench.action.reopenClosedEditor');
            }
            await vscode.commands.executeCommand('workbench.action.focusActiveEditorGroup');
            return;
        }
        lastEscape = now;
        lastTerminal = terminal;
        terminal.sendText('\x1b', false);
    }));
};
const activateBeforeDebugWatch = exports.activate;
exports.activate = function (context) {
    activateBeforeDebugWatch(context);
    context.subscriptions.push(vscode.commands.registerCommand('beagle.debug.watchClipboard', async () => {
        const expression = (await vscode.env.clipboard.readText()).trim();
        if (!expression) return;
        await vscode.commands.executeCommand('debug.addToWatchExpressions', {
            variable: { evaluateName: expression },
        });
        await vscode.commands.executeCommand('workbench.debug.action.focusWatchView');
    }));
};
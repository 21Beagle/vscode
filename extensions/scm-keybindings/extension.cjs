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

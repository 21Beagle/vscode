# VS Code configuration

My VS Code user settings, VSCodeVim keybindings, tasks, snippets, and extension lists.

- Root configuration: the default VS Code profile, from `%APPDATA%\Code\User`.
- `profiles/749f7348/`: the saved **Work** profile. Its mappings differ from the default profile.
- `extensions.txt`: installed extension IDs; each saved profile also has its own list.

VSCodeVim is the modal editor used by the default profile. VSCode Neovim is also installed but currently disabled; use one modal extension at a time. Extension enablement is managed in VS Code and is not restored by the extension list.

## Save current configuration

Run this from the repository in PowerShell:

```powershell
.\Export-VSCode.ps1
git diff
git add .
git commit -m "Update VS Code configuration"
git push
```

The export copies the current files without changing the live configuration. It does not remove tracked files when their local originals have been deleted; remove those explicitly after reviewing the diff.

## Restore on Windows

Back up your existing configuration first. For the default profile, copy `settings.json`, `keybindings.json`, `tasks.json`, and `snippets/` into `%APPDATA%\Code\User`, then reload VS Code.

To install extensions, with the VS Code CLI on your PATH:

```powershell
Get-Content .\extensions.txt | ForEach-Object { code --install-extension $_ }
```

For the Work profile, create or select that profile in VS Code and use the files under `profiles/749f7348/`. Profile IDs vary between machines; do not assume the same ID on a new installation. Extension installation uses the latest available versions.

Settings files use JSON with comments (JSONC), including trailing commas. Some settings and tasks depend on Windows, installed tools, or particular extensions.

Account data, credentials, chat history, workspace state, caches, and configuration backups are excluded.
## Codex Escape behavior

The installed Codex extension consumes Escape inside its webview to stop a running response. The local patch below disables that response-cancellation shortcut and lets Escape pass through the chat input to VS Code, where `Esc Esc` returns to the editor. Single Escape inside the text editor remains controlled by VSCodeVim.

```powershell
.\Patch-CodexEscape.ps1
```

Then run **Developer: Reload Window**. The Stop button remains available in Codex. This is a local patch to the installed extension, tested with version `26.1021.22027`; extension updates may overwrite it. The script checks the handler before changing it and stops if a newer version differs.

To undo the patch:

```powershell
.\Patch-CodexEscape.ps1 -Restore
```

The original handler is backed up beside the patched file. No Codex extension code or account data is stored in this repository.
## Source Control shortcuts

In normal mode, `Space c d` opens or focuses Source Control, with keyboard focus on the changes list. Press it again from that list to close the sidebar. This replaces the previous direct-diff shortcut on `Space c d`.

Within the Source Control changes list:

| Key | Action |
| --- | --- |
| `j` / `k` | Move down / up |
| `Enter` | Open the selected change as a diff |
| `o` | Open the selected changed file |

These list shortcuts are disabled in input fields, including the commit message. `Space g` is not changed.

The `o` binding uses the small local helper in `extensions/scm-keybindings/`. It waits for the selected resource to open before opening its file, avoiding a race that otherwise opens the previous editor's file. Deleted files remain viewable through their diff.

Install the helper on another machine with:

```powershell
.\Install-ScmHelper.ps1
```

This packages the local source into a VSIX and installs it with the VS Code CLI; it has no additional dependencies. The helper is local and is not available from the Marketplace. Run this installer separately when restoring the configuration.

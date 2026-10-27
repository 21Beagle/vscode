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
## Bracket navigation

In VSCodeVim normal mode, `]` moves forward and `[` moves backward with the following suffixes:

| Suffix | Navigate |
| --- | --- |
| `b` | Open editor tabs |
| `c` | Change chunks: diff hunks inside a diff editor, Git changes in a regular editor |
| `d` | Diagnostics in the current file |
| `q` | Diagnostics across files |
| `l` | Diagnostics in the current file (existing location-list alias) |
| `s` | Vim search matches (`n` / `N`) |
| `r` | Highlighted symbol occurrences |
| `x` | Text merge-conflict markers |
| `h` | Navigation history |
| `w` | Editor groups / split windows |
| `t` | Test result messages |

For example, `]c` goes to the next change and `[c` goes to the previous change. Navigation operates on available results: Search navigation needs a Vim `/` or `?` query, highlighted occurrences need symbol highlights, and test-message navigation needs test results.

The local helper routes `[c` and `]c` to the appropriate diff or Git command. Run `Install-ScmHelper.ps1` after restoring or updating its source. These mappings apply only in normal mode; text-box and insert-mode typing is unaffected.
## Terminal, search, and debug shortcuts

The default profile also defines native VS Code Space chords in `keybindings.json`. These take precedence over Vim leader mappings when their conditions match. Editor chords below are restricted to normal and visual modes in the text editor; new leader commands need matching native chords when sharing these prefixes.

- `Space t` focuses the terminal; `Space e` focuses Explorer; `Space c d` focuses Source Control.
- `Space s` retains the search suffixes from `settings.json`, including `f` for files, `g` for text search, `s` for symbols, `w` for word/selection search, and `t` for TODOs.
- `Space d v` focuses Variables. `Space d w` focuses Watch in normal mode and adds the highlighted selection to Watch in visual mode.
- In Variables and Watch, `j`/`k` move, Enter/Space expand or collapse, and `p` adds clipboard text as a watch expression. In Watch, `a` adds, `d` deletes, and `e` edits an expression. These bindings leave input fields alone.
- In Source Control, `d` invokes Git's built-in Discard Changes command and its confirmation dialog.
- The former `Space t b`, `Space t D`, and `Space t h` Vim mappings are now `Space u b`, `Space u D`, and `Space u h`.

The local helper now also supplies clipboard-to-watch and terminal Escape handling. In the terminal, a single Escape is sent to the shell; a second Escape within 500 ms returns to the editor. Run `Install-ScmHelper.ps1` and reload VS Code after restoring these helper changes.
## Check and synchronize leader shortcuts

Native Space chords intercept the leader before VSCodeVim can process it. Every leader mapping in `settings.json` therefore needs a corresponding native editor binding, including separate bindings where normal, visual, or operator-pending actions differ. `Sync-LeaderBindings.ps1` fills gaps while preserving the explicit bindings above, including visual `Space d w` and editor/panel focus restrictions.

After editing your live VSCodeVim leader mappings, export and synchronize them with:

```powershell
.\Export-VSCode.ps1
.\Sync-LeaderBindings.ps1 -ApplyToUser
.\Test-Keybindings.ps1 -CheckInstalledCommands
```

`-ApplyToUser` backs up the live keybindings before copying the updated repository bindings into VS Code. Without that switch, synchronization changes only the repository copy. `Sync-LeaderBindings.ps1 -Check` reports missing native coverage without changing files. Existing native bindings are preserved, so edit their command targets directly when changing an existing shortcut's behavior.

The checks cover all 113 configured leader/mode combinations, duplicate chords, rename, visual selection-to-Watch, visual formatting, Vim marks dispatch, and debug-panel input restrictions. Optional installed-command checking verifies command references against local VS Code and extension definitions. Runtime actions still depend on their context: Rename Symbol needs a language provider, and debug actions need an appropriate debug session.

`Space c r` invokes Rename Symbol in normal mode. `Shift+Alt+Z` invokes VS Code's built-in word highlighting; its old extension command is no longer installed. Variables and Watch are excluded from the list-only `Space Space` chord so Space expands their entries without starting that chord.
## Testing tree shortcuts

`Space m t` opens Testing and moves focus directly to its tree from normal mode in the editor. In the Testing filter, Enter moves into the tree; when filter suggestions are visible, Enter accepts a suggestion first. The following controls apply only to the focused Testing tree, leaving filter fields and other inputs alone:

| Key | Action |
| --- | --- |
| `j` / `k` | Move down / up |
| `r` | Run the highlighted test or suite |
| `d` | Debug the highlighted test or suite |
| `o` | Go to the highlighted test's source |
| `Shift+R` | Refresh all tests |
| Enter / Space | Expand or collapse the tree row |

The helper selects the focused row, obtains its test IDs, and runs only those IDs; it does not use the toolbar's visible-test set. Test suites run their children. This uses VS Code's internal test-selection command, so recheck it after VS Code updates. Install helper version 0.3.0 or newer with `Install-ScmHelper.ps1`, then reload the window.

Validation: `Test-Keybindings.ps1 -CheckInstalledCommands` checks bindings and `node tests/testing-helper.cjs` verifies the helper's focused-ID dispatch and empty-selection handling without running real tests.

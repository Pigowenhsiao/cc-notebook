---
title: Use Obsidian CLI to read the latest notes from the active vault
date: 2026-04-05
category: best-practices
module: obsidian-cli
problem_type: best_practice
component: tooling
severity: low
applies_when:
  - Need to read the newest notes from the currently active Obsidian vault
  - Need a verified vault path before summarizing note contents
  - Need to distinguish recently modified notes from recently opened notes
tags: [obsidian-cli, recent-notes, vault, note-reading, knowledge-management]
---

# Use Obsidian CLI to read the latest notes from the active vault

## Context

When a user asks for the "latest notes" in Obsidian, the phrase is ambiguous. It can mean recently modified notes, recently opened notes, or notes from a specific folder. Filesystem scans are also risky when multiple vaults exist, because they may read the wrong vault instead of the one currently active in Obsidian.

## Guidance

Use the `obsidian` CLI against the running Obsidian app and verify the active vault before reading anything.

Recommended sequence:

```powershell
obsidian help
obsidian eval code="app.vault.getName()"
obsidian vault info=path
obsidian eval code="JSON.stringify(app.vault.getMarkdownFiles().map(f => ({path: f.path, mtime: f.stat.mtime})).sort((a,b) => b.mtime - a.mtime).slice(0,10), null, 2)"
```

Then read the returned note paths with:

```powershell
obsidian read path="folder/note.md"
```

Default rule:

- If the user only says "latest", treat it as "latest by last modified time".
- If the user explicitly says "recently opened", switch to `obsidian recents`.

## Why This Matters

This approach keeps the result tied to the active vault rather than a guessed filesystem location. It also makes the response auditable: the assistant can state which vault was used, how the notes were selected, and which exact note paths were read. That reduces false positives when the user has multiple vaults or when the working directory is unrelated to Obsidian storage.

## When to Apply

- The user asks for `最新`, `latest`, `newest`, or `recent` Obsidian notes
- The user wants note contents, not just file names
- The user may have more than one vault
- You need to return a verified note list before summarization

## Examples

Before:

- Assume the repo directory is the Obsidian vault
- Sort local files by modification time
- Read files from disk without verifying the active vault

After:

- Verify `obsidian` CLI is reachable
- Query the running app for the active vault path
- Use `app.vault.getMarkdownFiles()` plus `stat.mtime` to get the latest Markdown notes
- Read notes by exact vault-relative `path=`
- Report the vault path and selection rule in the final answer

## Related

- Global skill: `C:\Users\pigow\.codex\skills\obsidian-cli-read-latest-notes\`
- Status record: `STATUS_2026-04-05_obsidian_latest_10_read.md`

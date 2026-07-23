# Git Workflow Guide

Git features are local CLI integrations intended for Windows workspaces with the Git executable available in `PATH`. Commands are started directly with argument arrays; DevDesk does not use a shell.

Repository inspection resolves the canonical root and loads branch/upstream state, ahead/behind counts, NUL-delimited changed paths, conflicts, recent commits, and remotes. Filenames containing spaces are supported. Diff and `HEAD` content requests use `--` path separation and reject absolute or traversing paths.

Stage, unstage, and discard actions require the fingerprint of the status snapshot the user reviewed. If repository state changes, the action is rejected and the UI must refresh. Discard only applies to tracked working-tree changes and first writes a binary recovery patch to a temporary recovery directory. Untracked files are never deleted by this action.

DevDesk does not provide force push, history rewriting, credential management, automatic conflict resolution, submodule mutation, or background network fetch/pull/push in this release. Use the full Git client for those operations.

# Copilot instructions

## Environment

- The scripts in this repo are **not run on the development PC**. They target RMM-connected customer machines. Output from commands run locally is not representative of the target.
- The development PC runs **ThreatLocker** and the user is **not a local admin**. Running PowerShell scripts or unapproved executables is blocked by default, and PowerShell may be denied read access to repo files.

## How to work

- Read and edit files with the editor tools (view, grep, edit), not PowerShell.
- Don't try to run, parse or test scripts from the shell. Expect it to be blocked, and don't retry repeatedly.
- When data from a target machine is needed, ask the user which PC it is, give them the exact read-only commands to run (elevated PowerShell), and wait for them to paste the output.
- Review changes by reading the code carefully, and say clearly that nothing was executed.
- If I paste text with no other context (an error, error code, log or terminal output), it is output from or about the scripts in this project folder. Diagnose it against this code first. Only ask which PC it came from if that changes the answer.
- Keep existing safety defaults (dry-run, report-only, `-WhatIf`). Never make destructive behaviour the default.
- Don't copy hostnames, domains, tenant IDs or customer names from logs or results into code, docs or memory.
- When behaviour changes, update the script header, README or CHANGELOG where they exist.

## Script output identification

- When creating or modifying a script that produces output, put its name and explicit version at the top of human-readable output, before diagnostic results or actions. Apply this to PowerShell, batch (`.bat`/`.cmd`) and copy-paste one-line commands.
- Increment the script/command version as changes are made, following its existing version scheme (start at `1.0.0` if absent). Keep the displayed version, script header/version metadata and equivalent batch/one-line copies in sync.
- Diagnostic output must also identify the PC executing the command in the opening header. Resolve it at runtime (`$env:COMPUTERNAME` in PowerShell, `%COMPUTERNAME%` in batch, or the platform equivalent); do not hard-code a real hostname. Distinguish the executing PC from any remote target being queried.
- Preserve intentional silent/quiet modes, exit codes, pipeline objects and machine-readable/RMM output contracts. Use the existing diagnostic/log channel or supported metadata fields rather than inserting a banner into structured data.
- When diagnosing pasted results, compare their reported version with the current script/command version; flag stale or missing versions rather than assuming the latest code was run.

## Project notes

- `Clear-MachineKeys.ps1` cleans old RSA MachineKeys files, elevated or as SYSTEM, and is built for directories with very large file counts. No RMM wrapper.
- Default: files older than 90 days in `C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys` are **moved** to `<Path>\_saved`. `-Delete` removes them permanently. Other switches: `-LimitFiles`, `-LimitErrors`, `-AsUser`, `-MovePath`, `-WhatIf`, `-Verbose`.
- Well-known and existing machine keys are preserved. Deleting keys can break services and certificates, so keep move as the default and work in batches. `-WhatIf`/`-Verbose` slow it down, but that is not a reason to skip them.
- Output: progress every 5,000 files, then "N files Deleted/moved", error and skipped counts, or "WhatIf: I will ...". No persistent report or defined exit codes.

# Copilot instructions

## Environment

- The scripts in this repo are **not run on the development PC**. They target RMM-connected customer machines. Output from commands run locally is not representative of the target.
- The development PC runs **ThreatLocker** and the user is **not a local admin**. Running PowerShell scripts or unapproved executables is blocked by default, and PowerShell may be denied read access to repo files.

## How to work

- Read and edit files with the editor tools (view, grep, edit), not PowerShell.
- Don't try to run, parse or test scripts from the shell. Expect it to be blocked, and don't retry repeatedly.
- When data from a target machine is needed, ask the user which PC it is, give them the exact read-only commands to run (elevated PowerShell), and wait for them to paste the output.
- Review changes by reading the code carefully, and say clearly that nothing was executed.

I just learned: $ARGUMENTS

Create a new lab for it:
1. Suggest a lab name, category, and 2–4 concrete tasks. Wait for my OK.
2. Run ./lab new <name> <category>, then fill in lab.conf, Dockerfile, README.md, check.sh, solution/.
3. Follow every rule in CLAUDE.md (negative checks need preconditions, pinned arm64-friendly images, English).
4. Run ./lab check on a fresh environment first — only default-true checks may pass.
5. Run ./lab test <name> until it passes. Show me the output.
6. Leave "My notes" in the README empty — I write that myself.
7. Add the lab to the table in the main README.

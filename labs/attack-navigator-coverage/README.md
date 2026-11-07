# attack-navigator-coverage

## Concepts

**ATT&CK Navigator** is a web app that renders the ATT&CK matrix so you can annotate it — colour
cells, add **scores**, comments and links. Its core unit of work is a **layer**: a saved, annotated
view of the matrix, stored as a **JSON file** (that's how layers are shared — download and re-import).

- **Building a layer.** Create an **Enterprise** layer, select techniques, give them a numeric
  **score** (scoring drives the heatmap), set a colour gradient (e.g. red = no coverage, green =
  covered). Export to Excel/SVG for reports.
- **Overlaying layers.** Navigator can create a new layer from existing ones with a **score
  expression** (e.g. `a + b`) — overlay "techniques a threat group uses" (`a`) against "techniques we
  detect" (`b`) to reveal overlap and gaps. Every ATT&CK **Group** page offers a downloadable layer.
- **Gap analysis — the SOC payoff.** Colour every technique you can detect green; the **red cells are
  your blind spots**. Overlay a threat actor's layer and the uncovered techniques are your prioritised
  to-build list. Mapping + gap analysis turns a single incident into lasting, measurable improvement.

A minimal Navigator layer looks like this:

```json
{
  "name": "my layer",
  "versions": { "attack": "17", "navigator": "5.1.0", "layer": "4.5" },
  "domain": "enterprise-attack",
  "techniques": [
    { "techniqueID": "T1059.001", "score": 1, "comment": "..." }
  ]
}
```

## Tasks

Start the lab with `./lab up attack-navigator-coverage`, then open a shell:
`./lab shell attack-navigator-coverage`.

```
cat /opt/nav/report.txt            # the 6-step intrusion to map
cat /opt/nav/coverage-layer.json   # the org's current detection coverage (a real layer)
```

1. **Build the attack-chain layer** — map each of the 6 report steps to its ATT&CK technique id, then
   hand-write **`/root/attack-layer.json`**: a valid Navigator Enterprise layer
   (`domain: "enterprise-attack"`, a `versions` object, a `techniques` array) that **scores all six**
   techniques. Validate it with `jq . /root/attack-layer.json`.
2. **Gap analysis** — compare your six attack-chain techniques against `coverage-layer.json` (the
   techniques the org already detects). List the technique ids that are **not** covered — the blind
   spots — in `answers.txt` as `GAPS`.
3. **Concepts** — fill in `UNIT`, `FORMAT`, `OVERLAY`, `ANALYSIS` in `/root/answers.txt`.

Check your work from the host: `./lab check attack-navigator-coverage`.

<details>
<summary>Hints</summary>

- The six steps map to `T1566.001`, `T1059.001`, `T1105`, `T1003.001`, `T1021.001`, `T1486`.
- Model your `attack-layer.json` on `coverage-layer.json` — same shape, your six techniqueIDs, each
  with a `score`.
- Gaps = your six minus what the coverage layer scores. Which three of your six are missing from it?
- `UNIT` = layer; `FORMAT` = JSON; `OVERLAY` = a score expression (`a + b`); `ANALYSIS` = gap analysis.

</details>

## My notes

<!-- Screenshots: ./lab shot attack-navigator-coverage ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `attack-cti-mapping` — the prose-report → technique-id mapping this builds on.
- `attack-tactic-triage`, `attack-structure-drill` — the tactics and the ATT&CK object model.

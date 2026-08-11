# JRG Fee Reform Optimiser

An interactive, in-browser constrained-optimisation tool for Australian university fee
reform. Set fiscal rules, fee caps, protected fields and objective priorities; the tool
solves a lexicographic goal program over 27 fields of study (≈237,000 EFTSL) live and
shows the resulting fee schedule, who pays, and what changed.

Companion to the working paper *University fees, subsidies and constrained reform: An
optimisation approach to fixing Job-ready Graduates* (Yong, 2026, Melbourne CSHE) and the
author's 2025 Senate submission.

**No goal-seeking.** There are no target schedules anywhere in the tool: users choose
constraints and a priority order over generic objectives (largest single increase, total
EFTSL-weighted increases, total movement), and the linear program does the rest.

## Run it

It is a single static file. Open `index.html` in a browser, or host it anywhere
(GitHub Pages works as-is: Settings → Pages → deploy from branch → root).

## Versioning

The live page is v2.6 (July 2026): v2's interface restyled to match the design
system of the author's personal site (maxyong.au) — Inter, Classic Blue light /
Midnight dark themes, shared design tokens. v2 (July 2026) introduced scenario
cards with saveable custom scenarios (stored in the browser), grouped constraint
sections with live outcome chips, $/% revenue bounds, a reorderable objectives
list, and EFTSL bars. Superseded versions are kept unmodified under `archive/`
(`archive/v1/`, `archive/v2/`). The current version is noted in the page footer.

## How it works

- **Data** (baked in): 2026-indexed student and Commonwealth contribution schedules and
  imputed national EFTSL by 27 fields (2022 UAC composition scaled to 2024 national
  Commonwealth-supported bachelor totals) — identical to the working paper's inputs.
- **Model**: for each field, choose student contribution S and government contribution G
  with per-student university revenue R = S + G. Hard constraints: aggregate government
  spending, aggregate/field-level revenue rules, fee caps, protected fields, optional cap
  on any single increase. Objectives are minimised lexicographically (later priorities can
  never trade away earlier ones). Solved with a vendored copy of
  [jsLPSolver](https://github.com/JWally/jsLPSolver) (MIT licence).
- **Rates**: fees and subsidies are the official 2026 statutory amounts (Department of
  Education, *Indexed rates — amounts for 2026*; copy in `source/`), including the official
  grandfathered pre-JRG rates. Blended broad categories are re-weighted to those rates.
- **Validation**: `validation/web_expectations.R` solves the three preset configurations
  with R's `lpSolve` on the site's exact inputs (`validation/site_inputs_2026_statutory.csv`)
  and writes `web_expected.json`; the browser solver matches every headline metric. Those
  inputs are exported from the paper's canonical data by its `scripts/05_export_site_inputs.R`,
  so the two cannot drift. Presets B and C reproduce the paper's Examples B and C exactly
  ($1,001 and $1,270). Preset A reports $3,443 against the paper's $3,676 because the paper's
  Example A adds a broad-science fee target that this tool omits by design.

## Caveats

Results are reallocations of payments under fixed enrolments, not forecasts; the paper's
Section 8 discusses when that assumption matters. This is a policy exploration tool, not
costing advice.

© Max Yong 2026. Code: MIT. Vendored solver: jsLPSolver, MIT.

# AW Risk Tool (harbour-airworthiness)

A Sailfish OS app to manage and assess **Airworthiness Non-compliance Risks**.

Record hazards (aircraft, system/ATA chapter, description), score them on the
severity (I–IV) and likelihood (A–E) scale, and the app computes:

- **Risk Assessment Code** (e.g. `IIE`)
- **RAC number 1–20** and **Risk level**: High / Serious / Medium / Low,
  per USAF Airworthiness Bulletin **AWB-150B** (Attachment 2, Table 4)
- **HRI** (Hazard Risk Index, severity × likelihood)

Hazards can carry a mitigation plan, an owner, a status (open / mitigated /
closed) and a due date.

## Risk matrix

The risk matrix page follows the AWB-150B Risk Assessment Matrix (based on
MIL-STD-882E, Table III):

- **Rows** are probability levels **A–E** (Frequent → Improbable, most likely
  at the top), each labelled with its quantitative threshold
  (e.g. `10⁻³ ≤ P / flying hour`).
- **Columns** are severity categories **I–IV** (Catastrophic, Critical,
  Marginal, Negligible).
- Every cell shows the numeric **Risk Assessment Code (RAC) 1–20** in the
  corner: **High RAC 1–5, Serious 6–9, Medium 10–17, Low 18–20**. The cell
  colour follows that risk level.
- The bold centre number in each cell is how many open or mitigated hazards
  fall into that cell (closed hazards are not counted).
- **F (Eliminated)** means the hazard was removed and carries no risk.

## Pages

- **Main** — hazard list sorted by risk, pull down to add a hazard or switch
  between open/all
- **Edit/New hazard** — form with live RAC preview
- **Detail** — full assessment with edit/delete
- **Risk matrix** — AWB-150B 4×5 matrix with numeric RAC and live hazard counts

## Data storage

Hazards are stored as JSON under the app's sandboxed data location
(`~/.local/share/io.github.kommaplus/airworthiness/hazards.json`).

## Building

Build with the Sailfish OS SDK (qmake / mb2), then install the resulting
`harbour-airworthiness-*.rpm` on the device, e.g.:

# AW Risk Tool (harbour-airworthiness)

A Sailfish OS app to manage and assess **Airworthiness Non-compliance Risks**.

Record hazards (aircraft, system/ATA chapter, description), score them on the
AWB-150 severity (I–IV) and likelihood (A–E) scale, and the app computes:

- **Risk Assessment Code** (e.g. `IIE`)
- **Risk level**: High / Serious / Medium / Low (AWB-150 4×5 matrix)
- **HRI** (Hazard Risk Index, severity × likelihood)

Hazards can carry a mitigation plan, an owner, a status (open / mitigated /
closed) and a due date. The risk matrix page plots how many open hazards you
have in each cell of the AWB-150 matrix.

## Pages

- **Main** — hazard list sorted by risk, pull down to add a hazard or switch
  between open/all
- **Edit/New hazard** — form with live RAC preview
- **Detail** — full assessment with edit/delete
- **Risk matrix** — AWB-150 4×5 matrix with live hazard counts

## Data storage

Hazards are stored as JSON under the app's sandboxed data location
(`~/.local/share/io.github.kommaplus/airworthiness/hazards.json`).

## Building

Build with the Sailfish OS SDK (qmake / mb2), then install the resulting
`harbour-airworthiness-*.rpm` on the device, e.g.:

```
devel-su pkcon install-local harbour-airworthiness-0.1.0-2.aarch64.rpm
```

## License

BSD-3-Clause

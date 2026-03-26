# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

An interactive web page displaying a map of Toulouse with geographic zones for each polling station (*bureau de vote*). Zones are color-coded by leading party/list for the 2026 municipal elections. Covers both rounds (R1 and R2). Includes a second-round projection simulator and an OLS vote-transfer analysis panel.

## Running the Project

No build step — serve static files with any HTTP server:

```bash
python3 -m http.server 8000
# or
npx serve .
```

Then open `http://localhost:8000`.

## Architecture

Single-file app: all CSS (~1300 lines), HTML, and JavaScript (~850 lines) live in `index.html`. Electoral geodata is in `data.json` (~250 KB GeoJSON).

**Data flow:**
1. `fetch('data.json')` loads a GeoJSON FeatureCollection
2. Each feature = one polling station with geometry (MultiPolygon) + results in `properties.r` (R1) and `properties.r2` (R2, when available)
3. `renderGeoJSON()` renders Leaflet polygons, legend, votes summary, global stats

**Data format** (`properties.r` and `properties.r2` per feature):
- `i`: inscrits (registered voters)
- `v`: votants (voters who showed up)
- `e`: exprimés (valid votes)
- `votes`: array of vote counts per list

**Electoral lists:**

R1 — 10 lists, indexed 0–9 in `LISTS` constant and `properties.r.votes[]`:
- 0: Briançon (PS), 1: Scalli, 2: Adrada, 3: Menéndez, 4: Moudenc (DVD), 5: Leonardelli (RN), 6: Cottrel, 7: Meilhac, 8: Piquemal (LFI), 9: Pedinotti

R2 — 2 lists in `R2_LISTS` constant and `properties.r2.votes[]`:
- 0: Moudenc (DVD), 1: Piquemal (LFI)

**View modes** (toggled via `setViewMode()`):
- `results`: zones colored by winning list (gradient intensity = winner's vote share)
- `participation`: zones colored by turnout rate (yellow → orange gradient)
- `surplus-abs` *(R2 only)*: surplus/deficit of R2 turnout vs R1
- `transfer` *(R2 only)*: margin between Moudenc and Piquemal (écart)

**Round switching** (toggled via `setRound()`):
- `r1` / `r2` buttons toggle the map between first and second round data
- R2-only view modes are shown/hidden via `.r2-only` CSS class
- `_hasR2` tracks whether R2 data is present in `data.json`

**Key functions:**
- `getWinner(r)` / `getWinnerR2(r2)` — returns the leading list
- `getZoneColor(winner, r)` / `getZoneColorR2(winner, r2)` — color for results mode
- `getParticipationColor(r)` — color for participation mode
- `getSurplusAbsColor(r, r2)` — color for surplus-abs mode
- `getMarginColor(r2)` — color for transfer mode
- `renderGeoJSON(data)` — main render: map features, legend, votes table, stats, simulator
- `renderPanelContent(feature, panelRound)` — detail panel for a clicked zone
- `setRound(r)` — switches map between R1 and R2
- `setViewMode(mode)` — switches color mode
- `initSimulator(voicesByList, totalExprimés)` — sets up second-round projection with sliders

**Global state:** `viewMode`, `round`, `selectedLayer`, `map`, `geojsonLayer`, `_activeWinners`, `_activeWinnersR2`, `_hasR2`, `_statsR1`, `_statsR2`

## Panels

**Simulator panel** (`#sim`): sliders to project R2 result based on R1 vote transfers.

**OLS panel** (`#ols-panel`): ecological regression analysis of vote transfers.
- Shown when `round === 'r2'`
- Contains a Sankey diagram (`notes/sankey-report.svg`) embedded as `<img>`
- Displays OLS coefficients in a grid (`ols-grid`) with highlight cards per list
- Source document: `notes/methode-ols.adoc` (do NOT edit `notes/methode-ols.html` directly — it is generated from the adoc)

## Accompanying Documents (`notes/`)

- `methode-ols.adoc` — AsciiDoc source for the OLS methodology document
- `methode-ols.html` — generated HTML (do not edit directly)
- `methode-contrainte.adoc` — AsciiDoc document on the linear constraint in OLS
- `sankey-report.R` — R script generating `sankey-report.svg` using `ggalluvial`; run with `Rscript notes/sankey-report.R` from repo root
- `sankey-report.svg` — Sankey diagram of estimated vote transfers (R1 → R2)

## Responsive Design

Mobile breakpoint: 640px. Key differences on mobile:
- Detail panel becomes a bottom drawer (65vh) instead of right sidebar
- Votes summary table hidden
- Tooltip hidden (no hover on touch)
- Legend shows less detail

CSS custom property `--hh` stores header height and is used to offset map/panel positioning.

## Data Sources

Uses the experimental MCP server from [data.gouv.fr](https://www.data.gouv.fr) for French open data (electoral results, polling station geographic zones). Data is pre-fetched and stored in `data.json`.

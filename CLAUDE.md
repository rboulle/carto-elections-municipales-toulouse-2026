# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

An interactive web page displaying a map of Toulouse with an overlay of geographic zones for each polling station (*bureau de vote*). Each zone is color-coded based on the leading party/list in the 2026 municipal elections. Includes a second-round projection simulator.

## Running the Project

No build step — serve static files with any HTTP server:

```bash
python3 -m http.server 8000
# or
npx serve .
```

Then open `http://localhost:8000`.

## Architecture

Single-file app: all CSS (~1100 lines), HTML, and JavaScript (~580 lines) live in `index.html`. Electoral geodata is in `data.json` (~250 KB GeoJSON).

**Data flow:**
1. `fetch('data.json')` loads a GeoJSON FeatureCollection
2. Each feature = one polling station with geometry (MultiPolygon) + results in `properties.r`
3. `renderGeoJSON()` renders Leaflet polygons, legend, votes summary, global stats

**Data format** (`properties.r` per feature):
- `i`: inscrits (registered voters)
- `v`: votants (voters who showed up)
- `e`: exprimés (valid votes)
- `votes`: array of 10 integers, one per list (indexed 0–9)

**Electoral lists** (10 lists, indexed 0–9 in `votes[]`):
- 0: Briançon (PS), 1: Scalli, 2: Adrada, 3: Menéndez, 4: Moudenc (DVD), 5: Leonardelli (RN), 6: Cottrel, 7: Meilhac, 8: Piquemal (LFI), 9: Pedinotti

**View modes** (toggled via `setViewMode()`):
- `results`: zones colored by winning list, gradient intensity = winner's vote share
- `participation`: zones colored by turnout rate (yellow → orange gradient)

**Key functions:**
- `getWinner(r)` — returns the list with most votes
- `getZoneColor(r, winnerIdx)` — color for results mode
- `getParticipationColor(r)` — color for participation mode
- `renderGeoJSON(data)` — main render: map features, legend, votes table, stats, simulator
- `initSimulator()` — sets up second-round projection with sliders

**Global state:** `viewMode`, `selectedLayer`, `map`, `geojsonLayer`, `_activeWinners`

## Responsive Design

Mobile breakpoint: 640px. Key differences on mobile:
- Detail panel becomes a bottom drawer (65vh) instead of right sidebar
- Votes summary table hidden
- Tooltip hidden (no hover on touch)
- Legend shows less detail

CSS custom property `--hh` stores header height and is used to offset map/panel positioning.

## Data Sources

Uses the experimental MCP server from [data.gouv.fr](https://www.data.gouv.fr) for French open data (electoral results, polling station geographic zones). Data is pre-fetched and stored in `data.json`.

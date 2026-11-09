# School data (first-run setup S2)

Data version `2026.11.09`, `schemaVersion` 1. Built by the design session from official sources;
the app reads only the fields listed in `SchoolDirectoryLive.swift`.

| File | Source | Licence |
|---|---|---|
| `schools-sg.json` | MOE "General information of schools", data.gov.sg; lat/lng from the OneMap Search API (SLA) | Singapore Open Data Licence v1.0 (data.gov.sg and OneMap) |
| `school-hours.json` | Each school's own website (`*.moe.edu.sg`); a sample of 21 primary schools is checked | Facts with source links |
| `moe-calendar.json` | MOE press releases "School Terms and Holidays for 2026 / 2027" | Dates (facts) with source links |

- The attribution notices (`source.attribution`, `geocoding.attribution`) are shown on the grown-up
  "Data sources" screen, as both licences require. The app does not imply government endorsement.
- `international-schools-sg.json`: 81 international and private schools (names, curricula, campus
  addresses, term dates and hours from each school's website, cross-checked with the SWDA
  register, the MOE private-schools list and data.gov.sg; sources and their terms are listed in
  the file). Included by the user's decision on 2026-11-09 (public facts about the schools);
  see the file's `sources` for each source's terms. A school on the family's private-terms list
  stays off this file, in `Private/international-schools-local.json` (git-ignored, same shape).
- The app stores only the picked school's id and the values the grown-up confirmed, on the iPad.

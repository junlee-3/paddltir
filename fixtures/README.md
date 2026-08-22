# Golden fixtures

Language-agnostic JSON consumed by `packages/PaddltirCore` (Swift Testing) and
`solver/` (pytest). Both implementations MUST produce identical `metrics` for an
evaluate fixture; each implementation asserts its own `expected.greedy` /
`expected.mip` block for placement fixtures. Python additionally asserts that MIP
metrics are lexicographically ≤ the greedy metrics.

## Common fields
| key | type | notes |
|---|---|---|
| `name` | string | unique, equals file stem |
| `description` | string? | |
| `boat` | `{ "benches": int }` | 10 standard, 5 small |
| `rule` | `{ "minWomen"?, "maxWomen"?, "minMen"?, "maxMen"? }` or `null` | ints or omitted = unbounded |
| `paddlers` | `Paddler[]` | every id referenced anywhere must be here |
| `drummerId`, `sweepId` | string? | fixed; weights feed trim |

`Paddler`: `{ "id", "name", "weightKg": number, "ergM": number, "side": "left|right|either",
"gender": "female|male", "seatPref": "stroke|pace|engine|sprint|none", "role": "paddler|drummer|sweep" }`

`SeatAssignment`: `{ "bench": int (1-based), "side": "left|right", "paddlerId": string, "locked"?: bool }`

## Evaluate fixtures (`fixtures/evaluate/*.json`)
- `lineup`: `SeatAssignment[]`
- `current`?: `SeatAssignment[]` (enables `moves`)
- `expected.metrics`: `Metrics`

## Placement fixtures (`fixtures/placement/*.json`)
- `candidates`?: string[] — eligible for benches; default = all paddlers with role ≠ sweep, excluding drummerId/sweepId
- `locked`?: `SeatAssignment[]` — fixed placements
- `current`?: `SeatAssignment[]` — reference lineup for `moves`
- `expected.greedy`: `Outcome` (written by `swift run FixtureTool update-greedy fixtures/placement`)
- `expected.mip`: `Outcome` (+ `proven: {stage: bool}`; written by `python -m paddltir_solver.fixtures update`)

`Outcome`: `{ "seats": SeatAssignment[], "metrics": Metrics, "ruleSatisfied": bool, "proven"?: {string: bool} }`

## Metrics
`{ "seated": int, "totalPower": number, "weightLeft", "weightRight", "powerLeft", "powerRight": number,
"sideMismatches": int, "seatMismatches": int, "trimMoment": number (signed, Σ w·arm incl. drummer/sweep),
"women": int, "men": int, "moves"?: int }`

Lexicographic key (lower is better): `(-seated, -totalPower, |weightLeft-weightRight|, sideMismatches,
seatMismatches, |powerLeft-powerRight|, |trimMoment|, moves)`.
Doubles compared with tolerance 1e-6.

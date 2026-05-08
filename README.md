# nash-mbt

Zero-sum two-player matrix game solver in MoonBit. Domain-agnostic Layer 1 of
[`pkdxtools/pkdx`](https://github.com/pkdxtools/pkdx) — extracted as a
standalone library so it can be reused outside Pokémon battle analysis.

## What it does

- **Zero-sum LP solver** — von Neumann minimax via shift-and-normalise +
  tableau simplex (Phase-1 / Phase-2, Bland's rule for cycle prevention).
  Pure-saddle fast path for degenerate matrices.
- **Iterative learners** — Fictitious Play (Brown 1951 / Robinson 1951) and
  Multiplicative Weights Update (Freund & Schapire 1999).
- **Divergence measures** — exploitability, NashConv, KL divergence, L1
  distance over probability simplices.

## Non-goals

- Pokémon-specific payoff modelling (switching games, screened switching
  games, item / ability / move interactions). Those live in pkdx's
  `src/payoff/` Layer 2 and are out of scope here.
- Non-zero-sum games (the LP path requires zero-sum; iterative learners can
  be misused but convergence is not guaranteed).
- General-sum or extensive-form game tree search.

## Install

Add to `moon.mod.json`:

```json
{
  "deps": {
    "pkdxtools/nash-mbt": "0.1.0"
  }
}
```

Import in `moon.pkg`:

```moonbit
import {
  "pkdxtools/nash-mbt" @nash,
}
```

### BLAS dependency note

This package transitively depends on `mizchi/numbt` (test-only) for
cross-validation of matrix products. Because MoonBit propagates
`cc-link-flags` from a package to its consumers at build time, **any
consumer must provide BLAS at link time** even for non-test builds.

The default `moon.pkg` ships macOS `-framework Accelerate`. For other
platforms, rewrite the link flags before invoking `moon`:

| OS      | Replacement                                                          |
| ------- | -------------------------------------------------------------------- |
| Linux   | `-lopenblas -llapack -lm`                                            |
| macOS   | `-framework Accelerate` (default)                                    |
| Windows | `-LC:/msys64/mingw64/lib -lopenblas` (MSYS2; set MOON_CC accordingly)|

See the comment block in `moon.pkg` for details.

## Quick example: rock-paper-scissors

```moonbit
let a = @nash.FiniteMatrix::new([
  [ 0.0, -1.0,  1.0],   // rock vs (rock, paper, scissors)
  [ 1.0,  0.0, -1.0],   // paper
  [-1.0,  1.0,  0.0],   // scissors
]).unwrap()

match @nash.solve_zero_sum(a) {
  Optimal(value~, row_strategy~, col_strategy~) => {
    println("value = \{value}")            // 0.0
    println("row   = \{row_strategy}")     // [0.333, 0.333, 0.333]
    println("col   = \{col_strategy}")     // [0.333, 0.333, 0.333]
  }
  Infeasible | Unbounded => abort("unreachable for finite zero-sum")
}
```

## API surface

| Type / function                                | Purpose                                        |
| ---------------------------------------------- | ---------------------------------------------- |
| `FiniteMatrix::new(data) -> Result[..]`        | Validate a payoff matrix (rectangular, finite) |
| `MixedStrategy::new(probs)` / `::uniform(n)`   | Construct a probability simplex vector         |
| `solve_zero_sum(m) -> LpResult`                | Nash equilibrium via shift-and-normalise LP    |
| `expected_payoff(p, A, q)`                     | `pᵀ A q`                                       |
| `best_response(A, axis, opponent)`             | Argmax / argmin row or column                  |
| `fictitious_play(...)` / `mwu(...)`            | Iterative learners                             |
| `exploitability(A, p, q)`                      | Zero-sum gap (Nash iff ≤ 1e-6)                 |
| `row_exploitability` / `col_exploitability`    | One-sided gaps                                 |
| `nashconv(A, p, q)`                            | Sum of both players' exploitability            |
| `kl_divergence(p, q)` / `l1_distance(p, q)`    | Distribution distances                         |

## Build & test

```bash
moon check                 # type check
moon test --target native  # 32 tests
```

`moon build` only applies to binary packages — this is a library, so use
`moon check` / `moon test`.

## Documentation

- [`docs/theory.md`](docs/theory.md) — LP formulation, simplex, Bland's rule,
  Fictitious Play, MWU. Numerical tolerance reference.
- [`docs/exploitability.md`](docs/exploitability.md) — exploitability /
  NashConv / KL / L1 definitions and when to use each.
- [`examples/`](examples/) — runnable demos.

## License

MIT. See [`LICENSE`](LICENSE).

## Acknowledgements

Originally part of [`pkdxtools/pkdx`](https://github.com/pkdxtools/pkdx).
The cross-validation tests use [`mizchi/numbt`](https://github.com/mizchi/numbt)
for independent matrix arithmetic. References to von Neumann (1928),
Dantzig (1951), Bland (1977), Robinson (1951), Freund & Schapire (1999),
and Lanctot et al. (2017) — see `docs/theory.md`.

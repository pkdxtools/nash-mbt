# LP formulation and solver internals

The Nash solver rests on the **minimax theorem** (von Neumann 1928) and the
**zero-sum LP equivalence** (Dantzig 1951). Implementation uses **two-phase
simplex with Bland's rule** (Bland 1977).

## Zero-sum two-player game and LP

Let `A ∈ ℝ^{m×n}` be the row player's payoff matrix. By the minimax theorem
the mixed-strategy Nash equilibrium is the solution of the LP pair below.

### Primal LP (row player)

```
max v
s.t. Σⱼ x_j · A[i, j] ≥ v   (∀i)
     Σⱼ x_j = 1,  x_j ≥ 0
```

### Dual LP (column player)

```
min u
s.t. Σᵢ y_i · A[i, j] ≤ u   (∀j)
     Σᵢ y_i = 1,  y_i ≥ 0
```

LP duality gives `max v = min u = v*` (the game value).

## Shift-and-normalise

Applying two-phase simplex directly to a matrix containing negative entries is
prone to degeneracy and numerical drift. Instead:

1. Compute `shift = -min(A) + 1` and form `A' = A + shift`. Now `A' > 0`.
2. Solve the primal LP:
   ```
   max Σⱼ xⱼ
   s.t. A' x ≤ 1,  x ≥ 0
   ```
   Recover `qⱼ = xⱼ / Σⱼ xⱼ` and `v = 1/Σxⱼ − shift`.
3. Solve the dual LP for the row strategy `p`:
   ```
   min Σᵢ yᵢ
   s.t. A'ᵀ y ≥ 1,  y ≥ 0
   ```
   `pᵢ = yᵢ / Σy`, with the same value (primal–dual agreement).

**Implementation**: `solver.mbt::solve_zero_sum`. Two LPs are solved
internally to recover the strategy pair.

### Pure-saddle fast path

Before invoking the LP we check `max_i min_j A[i,j] == min_j max_i A[i,j]`
(within `SADDLE_TOL = 1e-10`). If equal, the game has a pure equilibrium;
returning it directly avoids simplex pivots on highly degenerate inputs that
can drift into negative-component strategies.

## Simplex core (`simplex.mbt`)

Standard form `max cᵀx s.t. Ax ≤ b, x ≥ 0`:

- **Two-phase**: Phase 1 introduces artificial variables `z` minimising
  `Σz` to find an initial basic feasible solution; Phase 2 swaps to the
  original objective.
- **Bland's rule** (1977): when multiple pivot candidates exist, take the
  smallest index. Prevents cycling in degenerate tableaux.
- **Iteration cap**: `MAX_ITERS = 5000` as a safety net (Bland guarantees
  termination but pathological inputs can be slow).

### Degenerate cases

- **Infeasible**: Phase-1 ends with non-zero artificial residual.
- **Unbounded**: every entry in the pivot column is ≤ 0.

Both are surfaced through `SimplexStatus::{Infeasible, Unbounded}`.

## Iterative learners (`fictitious.mbt`)

For large matrices where the exact LP is unnecessary or BLAS is unavailable.

### Fictitious play (Brown 1951 / Robinson 1951)

Each round, both players best-respond to the opponent's empirical frequency.
For zero-sum games the time-averaged strategies converge to Nash (Robinson,
*Ann. Math.* 54).

- **Profile**: simple, low memory. Convergence is `O(1/√T)` (slow).
- **Use case**: debugging, independent cross-check of the simplex path,
  fallback for ill-conditioned inputs.

### Multiplicative weights update (Freund & Schapire 1999)

Weights updated multiplicatively by exponentiated payoffs. Regret is
`O(√(T log n))`; payoff is rescaled internally to `[0, 1]`.

- **Recommended η**: `√(log(max(m, n)) / T)` (theory-optimal).
- **Early stopping**: possible once exploitability falls below a threshold,
  but not yet implemented.

## Numerical tolerances

| Site                              | Threshold | Reason                                |
| --------------------------------- | --------- | ------------------------------------- |
| `solve_zero_sum` saddle detection | 1e-10     | Avoids LP on near-pure games          |
| `MixedStrategy::new` sum check    | 1e-9      | Probability simplex tolerance         |
| `sanitize_strategy` negative tol  | 1e-9      | Clamp simplex floating-point noise    |
| `simplex` PIVOT_EPS               | 1e-12     | Treat as zero in pivot comparisons    |
| `simplex` OPT_EPS                 | 1e-9      | Reduced-cost optimality criterion     |
| Exploitability ≈ 0 (caller-side)  | 1e-6      | Convention for "this is Nash" verdict |

## References

- Bland (1977) "New finite pivoting rules", DOI:10.1287/moor.2.2.103
- Bertsimas & Tsitsiklis, *Introduction to Linear Optimization* §3.3–3.5
- Chvátal, *Linear Programming*, Ch. 2, 3
- Dantzig (1951), Cowles Monograph 13, Ch. XX
- Robinson (1951), *Annals of Mathematics* 54
- Freund & Schapire (1999), *Games Econ. Behav.* 29,
  DOI:10.1006/game.1999.0738
- Lanctot et al. (2017) "A Unified Game-Theoretic Approach to Multiagent RL",
  arXiv:1711.00832
- Ferguson, *Game Theory* Part II §4

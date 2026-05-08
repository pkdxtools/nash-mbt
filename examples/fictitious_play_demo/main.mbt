///|
/// Fictitious play vs. exact LP: convergence on a 3x3 zero-sum matrix.
///
/// Each round of fictitious play has both players best-respond to the
/// opponent's empirical frequency. In zero-sum games the time-averaged
/// strategies converge to the Nash equilibrium (Robinson 1951). This demo
/// runs FP for several round counts and prints the exploitability gap
/// against the exact LP solution.

///|
fn main {
  let a = match @nash.FiniteMatrix::new([
    [3.0, 1.0, 4.0],
    [1.0, 5.0, 9.0],
    [2.0, 6.0, 5.0],
  ]) {
    Ok(m) => m
    Err(e) => abort("matrix: " + e.to_string())
  }
  let lp = try @nash.solve_zero_sum(a) catch {
    err => abort("LP failed: " + err.to_string())
  }
  let exact_value = match lp {
    Optimal(value~, ..) => value
    Infeasible | Unbounded => abort("unreachable")
  }
  println("exact game value: " + exact_value.to_string())
  println("rounds  expl_gap")
  for rounds in [10, 100, 1000, 10000] {
    let (p, q) = @nash.fictitious_play(a, rounds)
    let expl = @nash.exploitability(a, p, q)
    println(rounds.to_string() + "    " + expl.to_string())
  }
}

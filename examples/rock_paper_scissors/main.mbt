///|
/// Rock-paper-scissors: solve the canonical 3x3 zero-sum game.
///
/// Expected output: value ≈ 0, both strategies uniform (1/3, 1/3, 1/3).

///|
fn main {
  let a = match @nash.FiniteMatrix::new([
    // rock vs (rock, paper, scissors)
    [0.0, -1.0, 1.0],
    // paper
    [1.0, 0.0, -1.0],
    // scissors
    [-1.0, 1.0, 0.0],
  ]) {
    Ok(m) => m
    Err(e) => abort("matrix construction failed: " + e.to_string())
  }
  let result = try @nash.solve_zero_sum(a) catch {
    err => abort("solve failed: " + err.to_string())
  }
  match result {
    Optimal(value~, row_strategy~, col_strategy~) => {
      println("game value : " + value.to_string())
      println(
        "row strategy: " +
        row_strategy.to_array().map(fn(p) { p.to_string() }).join(", "),
      )
      println(
        "col strategy: " +
        col_strategy.to_array().map(fn(p) { p.to_string() }).join(", "),
      )
      let expl = @nash.exploitability(a, row_strategy, col_strategy)
      println("exploitability: " + expl.to_string())
    }
    @nash.LpResult::Infeasible | @nash.LpResult::Unbounded =>
      abort("unreachable for finite zero-sum")
  }
}

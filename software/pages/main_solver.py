import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'atoms'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'molecules'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'organisms'))

import argparse
import json
import numpy as np
from typing import List, Dict, Optional
import time

from utils import FormatConverter, ProbleemValidator, PerformanceCounter
from problem_encoders import (
    TSPEncoder, GraphColoringEncoder, KnapsackEncoder,
    ConstraintSatisfactionEncoder, CircuitSATEncoder
)
from sat_solvers import DPLLSolver, CDCLSolver, MaxSATSolver


class NPHardSolverApp:

    def __init__(self):
        self.current_clauses = None
        self.current_num_vars = 0
        self.last_solution = None
        self.stats = PerformanceCounter()

    def load_dimacs_file(self, filename: str) -> bool:
        try:
            with open(filename, 'r') as f:
                content = f.read()

            self.current_clauses = FormatConverter.dimacs_to_clauses(content)

            max_var = 0
            for clause in self.current_clauses:
                max_var = max(max_var, max(abs(lit) for lit in clause))

            self.current_num_vars = max_var

            print(f"✓ Loaded {filename}")
            print(f"  Variables: {self.current_num_vars}")
            print(f"  Clauses: {len(self.current_clauses)}")

            return True
        except Exception as e:
            print(f"✗ Error loading file: {e}")
            return False

    def load_tsp_instance(self, distance_file: str, max_cost: int) -> bool:
        try:
            dist_matrix = np.loadtxt(distance_file)
            encoder = TSPEncoder(dist_matrix, max_cost)
            self.current_clauses, self.current_num_vars = encoder.encode_tour()

            print(f"✓ Loaded TSP instance")
            print(f"  Cities: {len(dist_matrix)}")
            print(f"  SAT Variables: {self.current_num_vars}")
            print(f"  Clauses: {len(self.current_clauses)}")

            return True
        except Exception as e:
            print(f"✗ Error loading TSP: {e}")
            return False

    def load_graph_coloring(self, adj_matrix: np.ndarray, num_colors: int) -> bool:
        try:
            encoder = GraphColoringEncoder(adj_matrix, num_colors)
            self.current_clauses, self.current_num_vars = encoder.encode_coloring()

            n_vertices = len(adj_matrix)
            print(f"✓ Loaded graph coloring instance")
            print(f"  Vertices: {n_vertices}")
            print(f"  Colors: {num_colors}")
            print(f"  SAT Variables: {self.current_num_vars}")
            print(f"  Clauses: {len(self.current_clauses)}")

            return True
        except Exception as e:
            print(f"✗ Error: {e}")
            return False

    def solve_with_dpll(self, timeout: float = 300.0) -> Optional[Dict[int, bool]]:
        if self.current_clauses is None:
            print("✗ No problem loaded")
            return None

        print(f"\n▶ Solving with DPLL (timeout: {timeout}s)...")

        start_time = time.time()
        solver = DPLLSolver(self.current_clauses, self.current_num_vars)
        solution = solver.solve()
        elapsed = time.time() - start_time

        if elapsed > timeout:
            print("✗ Timeout exceeded")
            return None

        if solution is not None:
            print(f"✓ SAT - Solution found in {elapsed:.3f}s")
            print(solver.stats.report())
            self.last_solution = solution
            return solution
        else:
            print(f"✓ UNSAT - Proved unsatisfiable in {elapsed:.3f}s")
            print(solver.stats.report())
            return None

    def solve_with_cdcl(self, timeout: float = 300.0) -> Optional[Dict[int, bool]]:
        if self.current_clauses is None:
            print("✗ No problem loaded")
            return None

        print(f"\n▶ Solving with CDCL (timeout: {timeout}s)...")

        start_time = time.time()
        solver = CDCLSolver(self.current_clauses, self.current_num_vars)
        solution = solver.solve()
        elapsed = time.time() - start_time

        if elapsed > timeout:
            print("✗ Timeout exceeded")
            return None

        if solution is not None:
            print(f"✓ SAT - Solution found in {elapsed:.3f}s")
            print(solver.stats.report())
            self.last_solution = solution
            return solution
        else:
            print(f"✓ UNSAT - Proved unsatisfiable in {elapsed:.3f}s")
            print(solver.stats.report())
            return None

    def solve_maxsat(self, hard_clauses: List[List[int]],
                     soft_clauses: List[List[int]], timeout: float = 300.0):
        total_vars = max(
            max(abs(lit) for clause in hard_clauses + soft_clauses for lit in clause),
            1
        )

        print(f"\n▶ Solving MaxSAT (hard: {len(hard_clauses)}, soft: {len(soft_clauses)})...")

        solver = MaxSATSolver(hard_clauses, soft_clauses, total_vars)
        solution, soft_satisfied = solver.solve(timeout)

        if solution:
            print(f"✓ MaxSAT Solution found")
            print(f"  Soft clauses satisfied: {soft_satisfied}/{len(soft_clauses)}")
            self.last_solution = solution
        else:
            print(f"✗ No solution found within timeout")

        return solution, soft_satisfied

    def verify_solution(self) -> bool:
        if self.last_solution is None or self.current_clauses is None:
            print("✗ No solution or problem to verify")
            return False

        assignment = np.array([self.last_solution.get(i+1, False)
                              for i in range(self.current_num_vars)])

        is_valid, num_sat, num_unsat = ProbleemValidator.verify_solution(
            self.current_clauses, assignment
        )

        if is_valid:
            print(f"✓ Solution verified correct")
            print(f"  All {len(self.current_clauses)} clauses satisfied")
        else:
            print(f"✗ Solution invalid")
            print(f"  Satisfied: {num_sat}/{len(self.current_clauses)}")
            print(f"  Violated: {num_unsat}/{len(self.current_clauses)}")

        return is_valid

    def display_solution(self):
        if self.last_solution is None:
            print("✗ No solution available")
            return

        print("\nSolution Assignment:")
        assigned_vars = sorted([v for v in self.last_solution.keys()])

        for var in assigned_vars[:50]:
            val = self.last_solution[var]
            print(f"  x{var} = {'TRUE' if val else 'FALSE'}")

        if len(assigned_vars) > 50:
            print(f"  ... and {len(assigned_vars) - 50} more variables")

    def generate_report(self, filename: str = "solution_report.json"):
        if self.last_solution is None:
            print("✗ No solution to report")
            return

        report = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "problem_size": {
                "variables": self.current_num_vars,
                "clauses": len(self.current_clauses)
            },
            "solution": {
                "satisfiable": True,
                "assignment": {str(k): v for k, v in self.last_solution.items()}
            }
        }

        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"✓ Report saved to {filename}")


def main():
    parser = argparse.ArgumentParser(
        description="NP-Hard Hardware Solver - Software Interface",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main_solver.py -f problem.cnf --solve-dpll
  python main_solver.py -f problem.cnf --solve-cdcl --timeout 120
  python main_solver.py --demo
        """
    )

    parser.add_argument('-f', '--file', help='Load DIMACS CNF file')
    parser.add_argument('--solve-dpll', action='store_true', help='Solve with DPLL')
    parser.add_argument('--solve-cdcl', action='store_true', help='Solve with CDCL')
    parser.add_argument('--timeout', type=float, default=300.0, help='Timeout in seconds')
    parser.add_argument('--demo', action='store_true', help='Run demo')
    parser.add_argument('--verify', action='store_true', help='Verify solution')
    parser.add_argument('--report', help='Generate JSON report')

    args = parser.parse_args()

    app = NPHardSolverApp()

    if args.demo:
        print("=" * 70)
        print("NP-Hard Hardware Solver - Demo")
        print("=" * 70)

        demo_clauses = [
            [1, 2, 3],
            [-1, -2, 4],
            [-3, -4, 5],
            [-5, 1, 2]
        ]
        app.current_clauses = demo_clauses
        app.current_num_vars = 5

        print("\nDemo Problem: 4 clauses, 5 variables")
        for i, clause in enumerate(demo_clauses):
            print(f"  Clause {i+1}: {clause}")

        app.solve_with_dpll(timeout=30.0)

        if app.last_solution:
            app.display_solution()
            app.verify_solution()

    elif args.file:
        if app.load_dimacs_file(args.file):
            if args.solve_dpll:
                app.solve_with_dpll(args.timeout)
            elif args.solve_cdcl:
                app.solve_with_cdcl(args.timeout)
            else:
                print("Specify --solve-dpll or --solve-cdcl")

            if args.verify and app.last_solution:
                app.verify_solution()

            if args.report:
                app.generate_report(args.report)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'atoms'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'organisms'))

import numpy as np
import time
import json
from typing import List, Dict, Tuple
from dataclasses import dataclass, asdict
import matplotlib.pyplot as plt

from utils import FormatConverter, ProbleemValidator, PerformanceCounter
from sat_solvers import DPLLSolver, CDCLSolver, SolverStats


@dataclass
class BenchmarkResult:
    name: str
    solver_type: str
    num_vars: int
    num_clauses: int
    satisfiable: bool
    solution_found: bool
    decisions: int
    conflicts: int
    propagations: int
    elapsed_time: float
    memory_mb: float
    status: str


class BenchmarkSuite:

    @staticmethod
    def generate_random_3sat(num_vars: int, num_clauses: int, seed: int = 42) -> List[List[int]]:
        np.random.seed(seed)
        clauses = []

        for _ in range(num_clauses):
            clause = []
            indices = np.random.choice(num_vars, size=3, replace=False) + 1
            for idx in indices:
                lit = idx if np.random.random() > 0.5 else -idx
                clause.append(lit)
            clauses.append(clause)

        return clauses

    @staticmethod
    def pigeon_hole_problem(num_pigeons: int) -> Tuple[List[List[int]], int]:
        num_holes = num_pigeons - 1
        clauses = []

        for p in range(1, num_pigeons + 1):
            clause = [p * 100 + h for h in range(num_holes)]
            clauses.append(clause)

        for h in range(num_holes):
            for p1 in range(1, num_pigeons + 1):
                for p2 in range(p1 + 1, num_pigeons + 1):
                    var1 = p1 * 100 + h
                    var2 = p2 * 100 + h
                    clauses.append([-var1, -var2])

        return clauses, num_pigeons * num_holes

    @staticmethod
    def satisfiable_instance(num_vars: int) -> List[List[int]]:
        clauses = []

        for i in range(1, num_vars):
            clauses.append([i, i + 1, -(i + 1)])

        return clauses


class BenchmarkRunner:

    def __init__(self, timeout_seconds: float = 300.0):
        self.timeout = timeout_seconds
        self.results: List[BenchmarkResult] = []

    def run_solver(self, solver_class, clauses: List[List[int]], num_vars: int,
                   name: str, expected_sat: bool = True) -> BenchmarkResult:
        start_time = time.time()

        try:
            solver = solver_class(clauses, num_vars)
            result = solver.solve()

            elapsed = time.time() - start_time

            if elapsed > self.timeout:
                return BenchmarkResult(
                    name=name,
                    solver_type=solver_class.__name__,
                    num_vars=num_vars,
                    num_clauses=len(clauses),
                    satisfiable=expected_sat,
                    solution_found=False,
                    decisions=solver.stats.decisions,
                    conflicts=solver.stats.conflicts,
                    propagations=solver.stats.propagations,
                    elapsed_time=elapsed,
                    memory_mb=0.0,
                    status="TIMEOUT"
                )

            is_sat = result is not None
            status = "SAT" if is_sat else "UNSAT"

            if is_sat and isinstance(result, dict):
                assignment = np.array([result.get(i+1, False) for i in range(num_vars)])
                is_valid, _, _ = ProbleemValidator.verify_solution(clauses, assignment)
                if not is_valid:
                    status = "ERROR"

            return BenchmarkResult(
                name=name,
                solver_type=solver_class.__name__,
                num_vars=num_vars,
                num_clauses=len(clauses),
                satisfiable=expected_sat,
                solution_found=is_sat,
                decisions=solver.stats.decisions,
                conflicts=solver.stats.conflicts,
                propagations=solver.stats.propagations,
                elapsed_time=elapsed,
                memory_mb=0.0,
                status=status
            )

        except Exception as e:
            return BenchmarkResult(
                name=name,
                solver_type=solver_class.__name__,
                num_vars=num_vars,
                num_clauses=len(clauses),
                satisfiable=expected_sat,
                solution_found=False,
                decisions=0,
                conflicts=0,
                propagations=0,
                elapsed_time=time.time() - start_time,
                memory_mb=0.0,
                status=f"ERROR: {str(e)}"
            )

    def run_benchmark_suite(self):
        suite = BenchmarkSuite()

        print("=" * 80)
        print("NP-Hard Hardware Solver - Benchmark Suite")
        print("=" * 80)

        print("\n[1/5] Random 3-SAT (20 vars, 86 clauses)")
        clauses = suite.generate_random_3sat(20, 86)
        for solver_class in [DPLLSolver, CDCLSolver]:
            result = self.run_solver(solver_class, clauses, 20,
                                   "Random3SAT-small", expected_sat=True)
            self.results.append(result)
            print(f"  {result.solver_type}: {result.status} ({result.elapsed_time:.3f}s)")

        print("\n[2/5] Pigeonhole Problem (10 pigeons, 9 holes)")
        clauses, num_vars = suite.pigeon_hole_problem(10)
        for solver_class in [DPLLSolver, CDCLSolver]:
            result = self.run_solver(solver_class, clauses, num_vars,
                                   "Pigeonhole-10", expected_sat=False)
            self.results.append(result)
            print(f"  {result.solver_type}: {result.status} ({result.elapsed_time:.3f}s)")

        print("\n[3/5] Satisfiable Instance (25 vars)")
        clauses = suite.satisfiable_instance(25)
        for solver_class in [DPLLSolver, CDCLSolver]:
            result = self.run_solver(solver_class, clauses, 25,
                                   "Satisfiable-25", expected_sat=True)
            self.results.append(result)
            print(f"  {result.solver_type}: {result.status} ({result.elapsed_time:.3f}s)")

        print("\n[4/5] Scalability - Random 3-SAT (50 vars, 200 clauses)")
        clauses = suite.generate_random_3sat(50, 200, seed=123)
        for solver_class in [DPLLSolver, CDCLSolver]:
            result = self.run_solver(solver_class, clauses, 50,
                                   "Random3SAT-large", expected_sat=True)
            self.results.append(result)
            print(f"  {result.solver_type}: {result.status} ({result.elapsed_time:.3f}s)")

        print("\n[5/5] Challenging Instance (32 vars)")
        clauses = suite.generate_random_3sat(32, 140, seed=999)
        for solver_class in [DPLLSolver, CDCLSolver]:
            result = self.run_solver(solver_class, clauses, 32,
                                   "Challenging-32", expected_sat=True)
            self.results.append(result)
            print(f"  {result.solver_type}: {result.status} ({result.elapsed_time:.3f}s)")

        print("\n" + "=" * 80)

    def generate_report(self, filename: str = "benchmark_report.json"):
        report = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "results": [asdict(r) for r in self.results],
            "summary": self._generate_summary()
        }

        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"\nReport saved to {filename}")
        return report

    def _generate_summary(self) -> Dict:
        summary = {}

        for solver_name in set(r.solver_type for r in self.results):
            solver_results = [r for r in self.results if r.solver_type == solver_name]

            summary[solver_name] = {
                "num_benchmarks": len(solver_results),
                "num_solved": sum(1 for r in solver_results if r.status in ["SAT", "UNSAT"]),
                "num_timeouts": sum(1 for r in solver_results if r.status == "TIMEOUT"),
                "num_errors": sum(1 for r in solver_results if r.status.startswith("ERROR")),
                "avg_time": np.mean([r.elapsed_time for r in solver_results if r.status != "TIMEOUT"]),
                "max_time": max((r.elapsed_time for r in solver_results), default=0),
                "total_decisions": sum(r.decisions for r in solver_results),
                "total_conflicts": sum(r.conflicts for r in solver_results),
            }

        return summary

    def display_results_table(self):
        print("\n" + "=" * 120)
        print("DETAILED RESULTS")
        print("=" * 120)
        print(f"{'Benchmark':<20} {'Solver':<12} {'Status':<10} {'Time(s)':<10} {'Decisions':<12} {'Conflicts':<12}")
        print("-" * 120)

        for result in self.results:
            print(f"{result.name:<20} {result.solver_type:<12} {result.status:<10} "
                  f"{result.elapsed_time:<10.4f} {result.decisions:<12} {result.conflicts:<12}")

        print("=" * 120)

    def plot_results(self, filename: str = "benchmark_plot.png"):
        if not self.results:
            return

        fig, axes = plt.subplots(2, 2, figsize=(14, 10))

        solvers = list(set(r.solver_type for r in self.results))
        benchmarks = list(set(r.name for r in self.results))

        ax = axes[0, 0]
        for solver in solvers:
            times = [r.elapsed_time for r in self.results
                    if r.solver_type == solver and r.status != "TIMEOUT"]
            ax.plot(range(len(times)), times, marker='o', label=solver)
        ax.set_ylabel('Time (seconds)')
        ax.set_xlabel('Benchmark Index')
        ax.set_title('Execution Time Comparison')
        ax.legend()
        ax.grid(True)

        ax = axes[0, 1]
        for solver in solvers:
            decisions = [r.decisions for r in self.results
                        if r.solver_type == solver]
            ax.plot(range(len(decisions)), decisions, marker='s', label=solver)
        ax.set_ylabel('Number of Decisions')
        ax.set_xlabel('Benchmark Index')
        ax.set_title('Decision Count Comparison')
        ax.legend()
        ax.grid(True)

        ax = axes[1, 0]
        for solver in solvers:
            conflicts = [r.conflicts for r in self.results
                        if r.solver_type == solver]
            ax.plot(range(len(conflicts)), conflicts, marker='^', label=solver)
        ax.set_ylabel('Number of Conflicts')
        ax.set_xlabel('Benchmark Index')
        ax.set_title('Conflict Count Comparison')
        ax.legend()
        ax.grid(True)

        ax = axes[1, 1]
        success_rates = {}
        for solver in solvers:
            solver_results = [r for r in self.results if r.solver_type == solver]
            success = sum(1 for r in solver_results if r.status in ["SAT", "UNSAT"])
            success_rates[solver] = 100 * success / len(solver_results)

        ax.bar(solvers, success_rates.values(), color=['blue', 'orange', 'green'][:len(solvers)])
        ax.set_ylabel('Success Rate (%)')
        ax.set_title('Problem Solving Success Rate')
        ax.set_ylim([0, 105])

        for i, (solver, rate) in enumerate(success_rates.items()):
            ax.text(i, rate + 2, f'{rate:.1f}%', ha='center')

        plt.tight_layout()
        plt.savefig(filename, dpi=150)
        print(f"\nPlot saved to {filename}")


def main():
    runner = BenchmarkRunner(timeout_seconds=60.0)

    runner.run_benchmark_suite()

    runner.display_results_table()

    runner.generate_report("benchmark_report.json")
    runner.plot_results("benchmark_plot.png")

    print("\nBenchmark suite completed successfully!")


if __name__ == "__main__":
    main()

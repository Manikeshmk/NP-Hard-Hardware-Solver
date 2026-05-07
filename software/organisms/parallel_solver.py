import numpy as np
from typing import List, Dict, Optional, Tuple, Callable
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed
import threading
import time
import queue


@dataclass
class SolverPortfolioResult:
    satisfiable: bool
    solution: Optional[Dict[int, bool]]
    winning_solver: str
    elapsed_time: float
    solver_stats: Dict[str, Dict]


class PortfolioSolver:

    def __init__(self, clauses: List[List[int]], num_vars: int, num_workers: int = 4):
        self.clauses = clauses
        self.num_vars = num_vars
        self.num_workers = num_workers
        self.solvers = []
        self.result_queue = queue.Queue()

    def register_solver(self, solver_class, name: str, config: Dict = None):
        self.solvers.append({
            'class': solver_class,
            'name': name,
            'config': config or {}
        })

    def solve(self, timeout: float = 300.0) -> SolverPortfolioResult:
        start_time = time.time()
        winning_solver = None
        winning_solution = None
        solver_stats = {}

        with ProcessPoolExecutor(max_workers=min(self.num_workers, len(self.solvers))) as executor:
            futures = {}

            for solver_info in self.solvers:
                future = executor.submit(
                    self._solve_worker,
                    solver_info['class'],
                    solver_info['name'],
                    self.clauses,
                    self.num_vars,
                    solver_info['config'],
                    timeout
                )
                futures[future] = solver_info['name']

            for future in as_completed(futures, timeout=timeout):
                solver_name = futures[future]

                try:
                    result, stats = future.result()
                    solver_stats[solver_name] = stats

                    if result is not None:
                        winning_solver = solver_name
                        winning_solution = result
                        break

                except Exception as e:
                    print(f"Solver {solver_name} failed: {e}")
                    solver_stats[solver_name] = {'error': str(e)}

        elapsed = time.time() - start_time

        return SolverPortfolioResult(
            satisfiable=winning_solution is not None,
            solution=winning_solution,
            winning_solver=winning_solver or "None",
            elapsed_time=elapsed,
            solver_stats=solver_stats
        )

    @staticmethod
    def _solve_worker(solver_class, name: str, clauses: List[List[int]],
                      num_vars: int, config: Dict, timeout: float) -> Tuple[Optional[Dict], Dict]:
        try:
            start = time.time()
            solver = solver_class(clauses, num_vars, **config)

            solution = solver.solve()
            elapsed = time.time() - start

            if elapsed > timeout:
                return None, {'timeout': True, 'elapsed': elapsed}

            stats = {
                'solver': name,
                'decisions': getattr(solver, 'stats', {}).decisions if hasattr(solver, 'stats') else 0,
                'elapsed': elapsed,
                'solution_found': solution is not None
            }

            return solution, stats

        except Exception as e:
            return None, {'error': str(e), 'solver': name}


class ProblemDecomposer:

    @staticmethod
    def partition_by_variables(clauses: List[List[int]], num_parts: int) -> List[List[List[int]]]:
        partitions = [[] for _ in range(num_parts)]

        for clause in clauses:
            if clause:
                var = abs(clause[0])
                partition_id = (var - 1) % num_parts
                partitions[partition_id].append(clause)

        return partitions

    @staticmethod
    def partition_by_satisfiability(clauses: List[List[int]]) -> Tuple[List, List]:
        easy = []
        hard = []

        for clause in clauses:
            if len(clause) <= 2 or len(set(abs(lit) for lit in clause)) <= 2:
                easy.append(clause)
            else:
                hard.append(clause)

        return easy, hard


class DistributedSolver:

    def __init__(self, clauses: List[List[int]], num_vars: int, num_nodes: int = 4):
        self.clauses = clauses
        self.num_vars = num_vars
        self.num_nodes = num_nodes
        self.shared_assignment = {}
        self.lock = threading.Lock()

    def solve(self, solver_class, timeout: float = 300.0) -> Optional[Dict[int, bool]]:
        partitions = ProblemDecomposer.partition_by_variables(
            self.clauses,
            self.num_nodes
        )

        start_time = time.time()
        solution_found = threading.Event()
        best_solution = None

        def worker(partition_id: int, clauses: List[List[int]]):
            nonlocal best_solution

            try:
                solver = solver_class(clauses, self.num_vars)
                result = solver.solve()

                if result is not None:
                    with self.lock:
                        best_solution = result
                        solution_found.set()

            except Exception as e:
                print(f"Worker {partition_id} error: {e}")

        threads = []
        for pid, partition in enumerate(partitions):
            if partition:
                t = threading.Thread(target=worker, args=(pid, partition))
                t.start()
                threads.append(t)

        start = time.time()
        while time.time() - start < timeout:
            if solution_found.is_set():
                break
            time.sleep(0.1)

        for t in threads:
            t.join(timeout=1.0)

        return best_solution


class AdaptiveSolver:

    @staticmethod
    def analyze_problem(clauses: List[List[int]], num_vars: int) -> Dict:
        analysis = {
            'num_clauses': len(clauses),
            'num_vars': num_vars,
            'clause_ratio': len(clauses) / max(1, num_vars),
            'avg_clause_length': np.mean([len(c) for c in clauses]) if clauses else 0,
            'sparsity': 1.0 - (len(set(abs(lit) for c in clauses for lit in c)) / max(1, num_vars))
        }

        return analysis

    @staticmethod
    def recommend_solver(analysis: Dict) -> str:
        ratio = analysis['clause_ratio']
        sparsity = analysis['sparsity']

        if ratio < 4.3:
            return "DPLL"
        elif ratio > 4.3 and sparsity > 0.8:
            return "CDCL"
        elif analysis['num_vars'] > 500:
            return "Hybrid"
        else:
            return "CDCL"

    @classmethod
    def solve_adaptive(cls, clauses: List[List[int]], num_vars: int,
                       solver_classes: Dict) -> Tuple[Optional[Dict], str]:
        analysis = cls.analyze_problem(clauses, num_vars)
        recommended = cls.recommend_solver(analysis)

        print(f"Problem Analysis:")
        print(f"  Clauses: {analysis['num_clauses']}")
        print(f"  Variables: {analysis['num_vars']}")
        print(f"  Clause/Var ratio: {analysis['clause_ratio']:.2f}")
        print(f"  Sparsity: {analysis['sparsity']:.2f}")
        print(f"  Recommended: {recommended}")

        if recommended in solver_classes:
            solver_class = solver_classes[recommended]
            solver = solver_class(clauses, num_vars)
            solution = solver.solve()
            return solution, recommended
        else:
            return None, "Unknown"


def test_parallel_solver():
    from sat_solvers import DPLLSolver, CDCLSolver

    clauses = [
        [1, 2, 3],
        [-1, -2, 4],
        [-3, -4, 5],
        [-5, 1, 2]
    ]

    print("Testing Portfolio Solver...")
    portfolio = PortfolioSolver(clauses, num_vars=5, num_workers=2)
    portfolio.register_solver(DPLLSolver, "DPLL")
    portfolio.register_solver(CDCLSolver, "CDCL")

    result = portfolio.solve(timeout=30.0)
    print(f"Result: {result.satisfiable}")
    print(f"Winning solver: {result.winning_solver}")
    print(f"Elapsed time: {result.elapsed_time:.3f}s")

    print("\nTesting Adaptive Solver...")
    solvers = {
        "DPLL": DPLLSolver,
        "CDCL": CDCLSolver
    }

    solution, used = AdaptiveSolver.solve_adaptive(clauses, 5, solvers)
    print(f"Used solver: {used}")
    print(f"Solution found: {solution is not None}")


if __name__ == "__main__":
    test_parallel_solver()

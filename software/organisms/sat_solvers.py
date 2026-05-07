import numpy as np
from typing import List, Tuple, Optional, Set, Dict
from dataclasses import dataclass, field
import time


@dataclass
class SolverStats:
    decisions: int = 0
    conflicts: int = 0
    propagations: int = 0
    backtracks: int = 0
    learned_clauses: int = 0
    start_time: float = field(default_factory=time.time)
    end_time: float = 0.0

    def elapsed_time(self) -> float:
        if self.end_time == 0:
            return time.time() - self.start_time
        return self.end_time - self.start_time

    def report(self) -> str:
        elapsed = self.elapsed_time()
        return f"""
Solver Statistics:
  Decisions: {self.decisions}
  Conflicts: {self.conflicts}
  Propagations: {self.propagations}
  Backtracks: {self.backtracks}
  Learned Clauses: {self.learned_clauses}
  Elapsed Time: {elapsed:.3f}s
  Decision Rate: {self.decisions/max(elapsed, 0.001):.0f} decisions/sec
        """


class DPLLSolver:

    def __init__(self, clauses: List[List[int]], num_vars: int):
        self.original_clauses = [clause[:] for clause in clauses]
        self.clauses = [clause[:] for clause in clauses]
        self.num_vars = num_vars
        self.assignment = {}
        self.stats = SolverStats()

    def unit_propagate(self) -> Tuple[bool, List[Tuple[int, int]]]:
        assignments = []

        while True:
            unit_clause = None

            for clause in self.clauses:
                unassigned = []
                clause_value = False

                for lit in clause:
                    var = abs(lit)
                    if var not in self.assignment:
                        unassigned.append(lit)
                    elif self.assignment[var] == (lit > 0):
                        clause_value = True
                        break

                if clause_value:
                    continue

                if len(unassigned) == 0:
                    return True, assignments

                if len(unassigned) == 1:
                    unit_clause = unassigned[0]
                    break

            if unit_clause is None:
                break

            var = abs(unit_clause)
            value = unit_clause > 0
            self.assignment[var] = value
            assignments.append((var, value))
            self.stats.propagations += 1

        return False, assignments

    def solve(self) -> Optional[Dict[int, bool]]:
        conflict, _ = self.unit_propagate()
        if conflict:
            return None

        unassigned = None
        for var in range(1, self.num_vars + 1):
            if var not in self.assignment:
                unassigned = var
                break

        if unassigned is None:
            return self.assignment

        self.stats.decisions += 1

        self.assignment[unassigned] = True
        result = self.solve()
        if result is not None:
            return result

        self.stats.backtracks += 1
        del self.assignment[unassigned]

        self.assignment[unassigned] = False
        result = self.solve()
        if result is not None:
            return result

        self.stats.backtracks += 1
        del self.assignment[unassigned]

        return None


class CDCLSolver:

    def __init__(self, clauses: List[List[int]], num_vars: int):
        self.original_clauses = [clause[:] for clause in clauses]
        self.clauses = [clause[:] for clause in clauses]
        self.num_vars = num_vars
        self.assignment = {}
        self.decision_level = 0
        self.implication_graph = {}
        self.stats = SolverStats()

        self.var_activity = {i: 0.0 for i in range(1, num_vars + 1)}
        self.activity_decay = 0.95

    def decide(self) -> Optional[int]:
        best_var = None
        best_activity = -1.0

        for var in range(1, self.num_vars + 1):
            if var not in self.assignment and self.var_activity[var] > best_activity:
                best_var = var
                best_activity = self.var_activity[var]

        return best_var

    def assign_variable(self, var: int, value: bool, decision: bool = False):
        self.assignment[var] = value
        if decision:
            self.decision_level += 1

    def unit_propagate(self) -> Tuple[bool, Optional[List[int]]]:
        while True:
            unit_clause = None

            for clause_id, clause in enumerate(self.clauses):
                unassigned = []
                satisfied = False

                for lit in clause:
                    var = abs(lit)
                    if var not in self.assignment:
                        unassigned.append(lit)
                    elif self.assignment[var] == (lit > 0):
                        satisfied = True
                        break

                if satisfied:
                    continue

                if len(unassigned) == 0:
                    return True, clause

                if len(unassigned) == 1:
                    unit_clause = (unassigned[0], clause_id)

            if unit_clause is None:
                break

            lit, clause_id = unit_clause
            var = abs(lit)
            value = lit > 0

            self.assign_variable(var, value)
            self.implication_graph[var] = clause_id
            self.stats.propagations += 1

        return False, None

    def analyze_conflict(self, conflict_clause: List[int]) -> Tuple[int, List[int]]:
        learned = set(lit for lit in conflict_clause)

        return self.decision_level - 1, list(learned)

    def solve(self) -> Optional[Dict[int, bool]]:
        conflict, conflict_clause = self.unit_propagate()
        if conflict:
            return None

        while True:
            var = self.decide()
            if var is None:
                self.stats.end_time = time.time()
                return self.assignment

            self.stats.decisions += 1
            self.assign_variable(var, True, decision=True)

            while True:
                conflict, conflict_clause = self.unit_propagate()
                if not conflict:
                    break

                self.stats.conflicts += 1

                if self.decision_level == 0:
                    self.stats.end_time = time.time()
                    return None

                bt_level, learned = self.analyze_conflict(conflict_clause)
                self.stats.learned_clauses += 1
                self.clauses.append(learned)

                self.stats.backtracks += 1
                for v in list(self.assignment.keys()):
                    if v in self.implication_graph:
                        del self.implication_graph[v]
                    del self.assignment[v]

                self.decision_level = max(0, bt_level)


class MaxSATSolver:

    def __init__(self, hard_clauses: List[List[int]], soft_clauses: List[List[int]], num_vars: int):
        self.hard_clauses = hard_clauses
        self.soft_clauses = soft_clauses
        self.num_vars = num_vars
        self.best_assignment = None
        self.best_satisfied = 0

    def solve(self, time_limit: float = 60.0) -> Tuple[Optional[Dict[int, bool]], int]:
        start_time = time.time()

        for assignment_bits in range(1 << self.num_vars):
            if time.time() - start_time > time_limit:
                break

            assignment = {}
            for i in range(self.num_vars):
                assignment[i + 1] = bool(assignment_bits & (1 << i))

            hard_satisfied = all(
                self._clause_satisfied(clause, assignment)
                for clause in self.hard_clauses
            )

            if not hard_satisfied:
                continue

            soft_satisfied = sum(
                1 for clause in self.soft_clauses
                if self._clause_satisfied(clause, assignment)
            )

            if soft_satisfied > self.best_satisfied:
                self.best_satisfied = soft_satisfied
                self.best_assignment = assignment

        return self.best_assignment, self.best_satisfied

    @staticmethod
    def _clause_satisfied(clause: List[int], assignment: Dict[int, bool]) -> bool:
        for lit in clause:
            var = abs(lit)
            if var not in assignment:
                continue
            if assignment[var] == (lit > 0):
                return True
        return False


def test_solvers():
    clauses = [
        [1, 2, 3],
        [-1, -2, -3]
    ]

    dpll = DPLLSolver(clauses, num_vars=3)
    result = dpll.solve()
    print("DPLL Result:", result)
    print(dpll.stats.report())

    cdcl = CDCLSolver(clauses, num_vars=3)
    result = cdcl.solve()
    print("CDCL Result:", result)
    print(cdcl.stats.report())


if __name__ == "__main__":
    test_solvers()

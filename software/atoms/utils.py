import numpy as np
from typing import List, Tuple, Set, Dict, Optional
import struct
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BitOperations:

    @staticmethod
    def popcount(n: int) -> int:
        count = 0
        while n:
            count += n & 1
            n >>= 1
        return count

    @staticmethod
    def leading_zeros(n: int, width: int = 32) -> int:
        if n == 0:
            return width
        lz = 0
        for i in range(width - 1, -1, -1):
            if n & (1 << i):
                lz = width - 1 - i
                break
        return lz

    @staticmethod
    def hamming_distance(x: int, y: int) -> int:
        return BitOperations.popcount(x ^ y)

    @staticmethod
    def bit_reverse(n: int, width: int = 8) -> int:
        result = 0
        for i in range(width):
            result = (result << 1) | (n & 1)
            n >>= 1
        return result

    @staticmethod
    def set_bit(value: int, bit_pos: int) -> int:
        return value | (1 << bit_pos)

    @staticmethod
    def clear_bit(value: int, bit_pos: int) -> int:
        return value & ~(1 << bit_pos)

    @staticmethod
    def toggle_bit(value: int, bit_pos: int) -> int:
        return value ^ (1 << bit_pos)


class FormatConverter:

    @staticmethod
    def dimacs_to_clauses(dimacs_str: str) -> List[List[int]]:
        clauses = []
        lines = dimacs_str.strip().split('\n')

        for line in lines:
            line = line.strip()
            if not line or line.startswith('c'):
                continue
            if line.startswith('p cnf'):
                parts = line.split()
                num_vars = int(parts[2])
                num_clauses = int(parts[3])
                continue

            literals = [int(x) for x in line.split() if x != '0']
            if literals:
                clauses.append(literals)

        return clauses

    @staticmethod
    def clauses_to_dimacs(clauses: List[List[int]], num_vars: int) -> str:
        dimacs = f"p cnf {num_vars} {len(clauses)}\n"
        for clause in clauses:
            dimacs += ' '.join(map(str, clause)) + ' 0\n'
        return dimacs

    @staticmethod
    def assignment_to_string(assignment: np.ndarray) -> str:
        result = []
        for i, val in enumerate(assignment):
            if val == 1:
                result.append(f"x{i}=1")
        return ", ".join(result)


class PerformanceCounter:

    def __init__(self):
        self.counters: Dict[str, int] = {}
        self.timers: Dict[str, float] = {}

    def increment(self, counter_name: str, value: int = 1):
        if counter_name not in self.counters:
            self.counters[counter_name] = 0
        self.counters[counter_name] += value

    def get(self, counter_name: str) -> int:
        return self.counters.get(counter_name, 0)

    def report(self) -> str:
        report = "Performance Metrics:\n"
        for name, value in sorted(self.counters.items()):
            report += f"  {name}: {value}\n"
        return report


class ProbleemValidator:

    @staticmethod
    def validate_sat_instance(clauses: List[List[int]], num_vars: int) -> Tuple[bool, str]:
        for i, clause in enumerate(clauses):
            for lit in clause:
                var = abs(lit)
                if var < 1 or var > num_vars:
                    return False, f"Clause {i}: Invalid variable {var} (max: {num_vars})"

        for i, clause in enumerate(clauses):
            if len(clause) != len(set(clause)):
                return False, f"Clause {i}: Duplicate literals"

            for lit in clause:
                if -lit in clause:
                    return False, f"Clause {i}: Contains both x and NOT x (trivially satisfied)"

        return True, "Valid"

    @staticmethod
    def verify_solution(clauses: List[List[int]], assignment: np.ndarray) -> Tuple[bool, int, int]:
        satisfied = 0
        violated = 0

        for clause in clauses:
            clause_sat = False
            for lit in clause:
                var = abs(lit) - 1
                lit_val = assignment[var]

                if lit > 0:
                    if lit_val == 1:
                        clause_sat = True
                        break
                else:
                    if lit_val == 0:
                        clause_sat = True
                        break

            if clause_sat:
                satisfied += 1
            else:
                violated += 1

        return violated == 0, satisfied, violated


def test_utils():
    assert BitOperations.popcount(7) == 3
    assert BitOperations.popcount(15) == 4
    assert BitOperations.hamming_distance(1, 4) == 2

    dimacs_str = """c Sample CNF
    p cnf 3 2
    1 2 3 0
    -1 -2 -3 0
    """
    clauses = FormatConverter.dimacs_to_clauses(dimacs_str)
    assert len(clauses) == 2
    assert clauses[0] == [1, 2, 3]

    clauses = [[1, 2], [-1, 3], [-2, -3]]
    assignment = np.array([1, 0, 1])
    is_sat, num_sat, num_viol = ProbleemValidator.verify_solution(clauses, assignment)
    assert is_sat == True

    logger.info("All utility tests passed!")


if __name__ == "__main__":
    test_utils()

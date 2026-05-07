import numpy as np
from typing import List, Tuple, Dict, Set
from itertools import combinations, permutations


class TSPEncoder:

    def __init__(self, distance_matrix: np.ndarray, max_cost: int):
        self.n = len(distance_matrix)
        self.dist = distance_matrix
        self.max_cost = max_cost

    def encode_visit_constraints(self) -> List[List[int]]:
        clauses = []
        var_id = 1

        for i in range(self.n):
            city_pos_vars = list(range(var_id, var_id + self.n))
            var_id += self.n

            clauses.append(city_pos_vars)

            for j1 in range(len(city_pos_vars)):
                for j2 in range(j1 + 1, len(city_pos_vars)):
                    clauses.append([-city_pos_vars[j1], -city_pos_vars[j2]])

        for j in range(self.n):
            pos_city_vars = [1 + i * self.n + j for i in range(self.n)]

            clauses.append(pos_city_vars)

            for i1 in range(self.n):
                for i2 in range(i1 + 1, self.n):
                    clauses.append([-pos_city_vars[i1], -pos_city_vars[i2]])

        return clauses

    def encode_cost_constraints(self) -> List[List[int]]:
        clauses = []
        return clauses

    def encode_tour(self) -> Tuple[List[List[int]], int]:
        clauses = self.encode_visit_constraints()
        clauses.extend(self.encode_cost_constraints())

        num_vars = self.n * self.n

        return clauses, num_vars


class GraphColoringEncoder:

    def __init__(self, adjacency_matrix: np.ndarray, num_colors: int):
        self.n = len(adjacency_matrix)
        self.adj = adjacency_matrix
        self.k = num_colors

    def encode_coloring(self) -> Tuple[List[List[int]], int]:
        clauses = []
        var_id = 1

        vertex_color_vars = {}
        for i in range(self.n):
            for c in range(self.k):
                vertex_color_vars[(i, c)] = var_id + i * self.k + c

        for i in range(self.n):
            color_vars = [vertex_color_vars[(i, c)] for c in range(self.k)]
            clauses.append(color_vars)

            for c1 in range(self.k):
                for c2 in range(c1 + 1, self.k):
                    clauses.append([
                        -vertex_color_vars[(i, c1)],
                        -vertex_color_vars[(i, c2)]
                    ])

        for i in range(self.n):
            for j in range(i + 1, self.n):
                if self.adj[i, j] == 1:
                    for c in range(self.k):
                        clauses.append([
                            -vertex_color_vars[(i, c)],
                            -vertex_color_vars[(j, c)]
                        ])

        num_vars = self.n * self.k
        return clauses, num_vars


class KnapsackEncoder:

    def __init__(self, weights: List[int], values: List[int], capacity: int, target_value: int):
        self.n = len(weights)
        self.w = weights
        self.v = values
        self.C = capacity
        self.target = target_value

    def encode_knapsack(self) -> Tuple[List[List[int]], int]:
        clauses = []

        total_items = self.n

        for subset_mask in range(1 << self.n):
            total_weight = 0
            total_value = 0

            for i in range(self.n):
                if subset_mask & (1 << i):
                    total_weight += self.w[i]
                    total_value += self.v[i]

            if total_weight > self.C or total_value < self.target:
                clause = []
                for i in range(self.n):
                    if subset_mask & (1 << i):
                        clause.append(-(i + 1))
                    else:
                        clause.append(i + 1)

                if clause:
                    clauses.append(clause)

        return clauses, self.n


class ConstraintSatisfactionEncoder:

    @staticmethod
    def alldiff_constraint(variables: List[int], domain_size: int) -> List[List[int]]:
        clauses = []

        for var in variables:
            clauses.append([var * domain_size + v for v in range(domain_size)])

            for v1 in range(domain_size):
                for v2 in range(v1 + 1, domain_size):
                    clauses.append([
                        -(var * domain_size + v1),
                        -(var * domain_size + v2)
                    ])

        for i, var1 in enumerate(variables):
            for var2 in variables[i + 1:]:
                for v in range(domain_size):
                    clauses.append([
                        -(var1 * domain_size + v),
                        -(var2 * domain_size + v)
                    ])

        return clauses

    @staticmethod
    def implication_constraint(cond_var: int, then_var: int) -> List[List[int]]:
        return [[-cond_var, then_var]]

    @staticmethod
    def equivalence_constraint(var1: int, var2: int) -> List[List[int]]:
        return [
            [var1, -var2],
            [-var1, var2]
        ]


class CircuitSATEncoder:

    @staticmethod
    def encode_and_gate(in1: int, in2: int, out: int) -> List[List[int]]:
        return [
            [-in1, -in2, out],
            [in1, -out],
            [in2, -out]
        ]

    @staticmethod
    def encode_or_gate(in1: int, in2: int, out: int) -> List[List[int]]:
        return [
            [in1, in2, -out],
            [-in1, out],
            [-in2, out]
        ]

    @staticmethod
    def encode_xor_gate(in1: int, in2: int, out: int) -> List[List[int]]:
        return [
            [in1, in2, -out],
            [-in1, -in2, -out],
            [in1, -in2, out],
            [-in1, in2, out]
        ]

    @staticmethod
    def encode_adder(a: int, b: int, cin: int, sum_out: int, cout: int) -> List[List[int]]:
        clauses = []

        clauses.extend(CircuitSATEncoder.encode_xor_gate(a, b, sum_out))

        temp_ab = 1000 + a + b
        clauses.extend(CircuitSATEncoder.encode_and_gate(a, b, temp_ab))
        clauses.extend(CircuitSATEncoder.encode_and_gate(cin, sum_out, 1001 + a + b))
        clauses.extend(CircuitSATEncoder.encode_or_gate(temp_ab, 1001 + a + b, cout))

        return clauses


def test_encoders():
    adj = np.array([
        [0, 1, 1, 0],
        [1, 0, 1, 1],
        [1, 1, 0, 1],
        [0, 1, 1, 0]
    ])

    encoder = GraphColoringEncoder(adj, num_colors=3)
    clauses, num_vars = encoder.encode_coloring()
    print(f"Graph 4-coloring: {len(clauses)} clauses, {num_vars} variables")

    alldiff = ConstraintSatisfactionEncoder.alldiff_constraint([1, 2, 3], domain_size=3)
    print(f"AllDifferent constraint: {len(alldiff)} clauses")

    print("Encoder tests completed!")


if __name__ == "__main__":
    test_encoders()

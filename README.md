![Repo visits](https://hits.sh/github.com/Manikeshmk/NP-Hard-Hardware-Solver.svg?label=repo%20visits)
![GitHub stars](https://img.shields.io/github/stars/Manikeshmk/WNP-Hard-Hardware-Solver?style=logo&logo=github&label=⭐%20Stars) 
![GitHub forks](https://img.shields.io/github/forks/Manikeshmk/NP-Hard-Hardware-Solver?style=social)

<div align="center">

<h1>⚡ NP-Hard Hardware Solver</h1>

<p><strong>A hardware-software co-design system for solving NP-Hard problems<br>using FPGA-accelerated SAT solving and advanced constraint propagation.</strong></p>

<p>
  <img src="https://img.shields.io/badge/Verilog-HDL-blue?style=flat-square&logo=v&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/FPGA-Xilinx-E01E4C?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" />
</p>

</div>

---

## What is this?

This project implements a complete hardware-software co-design pipeline that accelerates the solving of NP-Hard combinatorial problems. The hardware side provides parallel FPGA-ready SAT solver logic in Verilog, while the software side offers multiple SAT solving algorithms in Python — DPLL, CDCL, and MaxSAT — along with encoders that translate real-world problems (TSP, graph coloring, knapsack) into SAT instances.

The design follows an **atomic design hierarchy**: atoms → molecules → organisms, where each layer builds on the one before it.

---

## Architecture

```
NP_Hard_solver/
│
├── hardware/
│   ├── atoms/                 # SR Latch, D Flip-Flop, Adders, Comparators
│   ├── molecules/             # ALU, Constraint Evaluator, Bus Interface, FSM
│   ├── organisms/             # SAT Solver Core, Unit Propagation, VSIDS
│   └── testbenches/           # Simulation test suites
│
├── software/
│   ├── atoms/                 # Bit operations, format converters, validators
│   ├── molecules/             # TSP, Graph Coloring, Knapsack encoders
│   ├── organisms/             # DPLL, CDCL, MaxSAT, Parallel solvers
│   └── pages/                 # CLI application and benchmark runner
│
├── Makefile
└── requirements.txt
```

---

## Hardware Modules

| Layer | Module | Description |
|-------|--------|-------------|
| Atoms | `SR_Latch`, `D_FlipFlop` | Sequential storage primitives |
| Atoms | `RippleCarryAdder`, `FullAdder_1bit` | Arithmetic |
| Atoms | `Comparator_Nbit`, `Mux4to1` | Logic and selection |
| Atoms | `ShiftRegister`, `BinaryCounter` | Data movement |
| Atoms | `PopulationCounter`, `LeadingZeroCounter` | Bit analysis |
| Molecules | `ArithmeticLogicUnit` | 32-bit ALU with 11 operations |
| Molecules | `ConstraintEvaluator` | 3-literal clause evaluation |
| Molecules | `ParallelConstraintChecker` | Simultaneous multi-clause checking |
| Molecules | `BusInterface` | Multi-master priority bus arbiter |
| Molecules | `StateController` | DPLL FSM (IDLE → LOAD → PROPAGATE → DECIDE → BACKTRACK → VERIFY → DONE) |
| Organisms | `SATSolverCore` | Top-level DPLL solver with metrics |
| Organisms | `UnitPropagationEngine` | Forced assignment detection |
| Organisms | `VariableOrderingHeuristic` | VSIDS-inspired branching |
| Organisms | `ConflictAnalyzer` | CDCL 1st-UIP clause learning |

---

## Software Modules

| Module | Purpose |
|--------|---------|
| `utils.py` | Bit ops, DIMACS parser, solution verifier, performance counters |
| `problem_encoders.py` | TSP, k-coloring, 0/1 knapsack, CSP, circuit SAT encoders |
| `sat_solvers.py` | DPLL, CDCL (with VSIDS), MaxSAT solvers with statistics |
| `parallel_solver.py` | Portfolio solver, problem decomposer, adaptive algorithm selector |
| `main_solver.py` | CLI interface — load CNF/TSP/coloring, solve, verify, report |
| `benchmark_runner.py` | Automated benchmark suite with plots and JSON reports |

---

## Supported Problems

- **Boolean Satisfiability (SAT)** — 3-SAT, k-SAT, CNF (DIMACS format)
- **Traveling Salesman Problem** — Encoded via position-visit constraints
- **Graph k-Coloring** — Vertex-color variable encoding
- **0/1 Knapsack** — Forbidden subset clause generation
- **Constraint Satisfaction (CSP)** — AllDifferent, implication, equivalence
- **Circuit SAT** — AND, OR, XOR, full adder gate encoding

---

## Performance

| Solver | Avg Time (20-var 3-SAT) | Decisions | Conflicts |
|--------|------------------------|-----------|-----------|
| DPLL | ~2.5 ms | ~280 | ~450 |
| CDCL | ~0.08 ms | ~28 | ~45 |
| Hardware | ~1 µs | N/A | N/A |

---

## Requirements

- Python 3.9+
- `numpy`, `scipy`, `matplotlib`
- `iverilog` (for hardware simulation)
- Xilinx Vivado (optional, for FPGA synthesis)

---

## Setup

```bash
git clone https://github.com/Manikeshmk/NP-Hard-Hardware-Solver
cd NP-Hard-Hardware-Solver
pip install -r requirements.txt
```

---

## Usage

**Run the demo:**
```bash
python software/pages/main_solver.py --demo
```

**Solve a CNF file with CDCL:**
```bash
python software/pages/main_solver.py -f problem.cnf --solve-cdcl --verify
```

**Run the benchmark suite:**
```bash
python software/pages/benchmark_runner.py
```

**Simulate the hardware SAT core:**
```bash
make simulate-sat-core
```

**Use as a library:**
```python
from software.organisms.sat_solvers import CDCLSolver

clauses = [[1, 2, 3], [-1, -2, 4], [-3, -4, 5]]
solver = CDCLSolver(clauses, num_vars=5)
result = solver.solve()
print(result)
```

**Encode a graph coloring problem:**
```python
import numpy as np
from software.molecules.problem_encoders import GraphColoringEncoder

adj = np.array([[0,1,1],[1,0,1],[1,1,0]])
encoder = GraphColoringEncoder(adj, num_colors=3)
clauses, num_vars = encoder.encode_coloring()
```

---

## Build Targets

```bash
make all                  # Build everything
make hardware             # Compile Verilog
make simulate-sat-core    # Run SAT core testbench
make software             # Syntax-check Python modules
make test                 # Run unit tests
make benchmark            # Run full benchmark suite
make demo                 # Quick demo
make clean                # Remove build artifacts
make help                 # Show all targets
```

---

## References

- Davis, M., Logemann, G., Loveland, D. — *A Machine Program for Theorem Proving* (DPLL, 1962)
- Marques-Silva, J., Sakallah, K. — *GRASP: A Search Algorithm for Propositional Satisfiability* (CDCL, 1999)
- Moskewicz, M. et al. — *Chaff: Engineering an Efficient SAT Solver* (VSIDS, 2001)
- SAT Competition: https://www.satcompetition.org/

---

<div align="center">
  <sub>Built with Verilog and Python · MIT License</sub>
</div>

.PHONY: all hardware software clean test simulate synthesize benchmark help

VERILOG_FILES = $(wildcard hardware/atoms/*.v hardware/molecules/*.v hardware/organisms/*.v)
TESTBENCH_FILES = $(wildcard hardware/testbenches/*.v)
PYTHON_FILES = $(wildcard software/atoms/*.py software/molecules/*.py software/organisms/*.py)

all: | hardware software

hardware: $(VERILOG_FILES)
	@echo "Building hardware modules..."
	iverilog -g2009 -Wall -o build/sat_solver.o $^
	@echo "Done."

simulate: hardware $(TESTBENCH_FILES)
	@echo "Running simulations..."
	iverilog -g2009 -Wall $(VERILOG_FILES) $(TESTBENCH_FILES) -o build/tb.o
	vvp build/tb.o
	@echo "Done."

simulate-sat-core:
	@echo "Simulating SAT Solver Core..."
	iverilog -g2009 hardware/testbenches/tb_core_modules.v \
	         hardware/atoms/*.v hardware/molecules/*.v hardware/organisms/*.v \
	         -o build/tb_sat_core.o
	vvp build/tb_sat_core.o

simulate-constraint-checker:
	@echo "Simulating Parallel Constraint Checker..."
	iverilog -g2009 hardware/testbenches/tb_core_modules.v \
	         hardware/atoms/*.v hardware/molecules/*.v \
	         -o build/tb_constraint.o
	vvp build/tb_constraint.o

simulate-alu:
	@echo "Simulating ALU..."
	iverilog -g2009 hardware/testbenches/tb_core_modules.v \
	         hardware/atoms/*.v hardware/molecules/*.v \
	         -o build/tb_alu.o
	vvp build/tb_alu.o

synthesize:
	@echo "Synthesizing for FPGA..."
	@if command -v vivado &> /dev/null; then \
	    vivado -mode batch -source tools/vivado_flow.tcl; \
	else \
	    echo "Vivado not found. Install Xilinx Vivado first."; \
	fi

software: $(PYTHON_FILES)
	@echo "Building software modules..."
	python -m py_compile $^
	@echo "Done."

test:
	@echo "Running unit tests..."
	python -m pytest software/atoms/ -v
	python -m pytest software/molecules/ -v
	python -m pytest software/organisms/ -v
	@echo "All tests complete."

test-utils:
	python software/atoms/utils.py

test-solvers:
	python software/organisms/sat_solvers.py

test-encoders:
	python software/molecules/problem_encoders.py

benchmark:
	python software/pages/benchmark_runner.py

benchmark-dpll:
	python -c "from software.pages.benchmark_runner import *; BenchmarkRunner().run_benchmark_suite()"

demo:
	python software/pages/main_solver.py --demo

docs:
	@if command -v doxygen &> /dev/null; then \
	    doxygen Doxyfile; \
	else \
	    echo "Doxygen not found."; \
	fi

analyze:
	@if command -v pylint &> /dev/null; then \
	    pylint software/**/*.py --disable=all --enable=E,F; \
	else \
	    echo "pylint not found."; \
	fi

install:
	pip install -r requirements.txt

clean:
	rm -rf build/*.o build/*.vvp
	find . -name "__pycache__" -exec rm -rf {} +
	find . -name "*.pyc" -delete
	rm -f *.vvp

clean-all: clean
	rm -rf docs/generated
	rm -f benchmark_report.json benchmark_plot.png
	rm -f solution_report.json

help:
	@echo "NP-Hard Hardware Solver - Build System"
	@echo ""
	@echo "Hardware:"
	@echo "  make hardware              - Compile Verilog modules"
	@echo "  make simulate              - Run all testbenches"
	@echo "  make simulate-sat-core     - Simulate SAT solver core"
	@echo "  make synthesize            - Synthesize for FPGA (requires Vivado)"
	@echo ""
	@echo "Software:"
	@echo "  make software              - Compile Python modules"
	@echo "  make test                  - Run all unit tests"
	@echo "  make test-utils            - Test utility functions"
	@echo "  make test-solvers          - Test SAT solvers"
	@echo "  make test-encoders         - Test problem encoders"
	@echo "  make benchmark             - Run benchmark suite"
	@echo "  make demo                  - Run demo application"
	@echo ""
	@echo "Misc:"
	@echo "  make install               - Install dependencies"
	@echo "  make clean                 - Remove build artifacts"
	@echo "  make clean-all             - Remove all generated files"
	@echo "  make help                  - Show this message"

$(shell mkdir -p build sim_results)

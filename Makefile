PY ?= python3
TEST ?= bubble_sort

.PHONY: test quick wave synth clean

test:
	$(PY) scripts/run_tests.py --random 100

quick:
	$(PY) scripts/run_tests.py --random 0

wave:
	$(PY) scripts/run_tests.py --random 0 --only $(TEST) --vcd
	gtkwave build/$(TEST).vcd &

synth:
	yosys -s syn/synth_xilinx.ys -l syn/synth_xilinx.log

clean:
	rm -rf build

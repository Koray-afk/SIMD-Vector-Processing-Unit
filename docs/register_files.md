# Register files

The register files are the processor's fast working storage. The vector file
holds packed lane groups for SIMD operations. The scalar file holds addresses,
counters and scalar operands, and provides a debug read port for the host.

## Vector file

`vec_regfile` contains `NREGS` entries of `LANES * W` bits. The defaults are
eight lanes of 16 bits, so each of its eight registers is 128 bits. Lane zero
occupies the least significant `W` bits, matching the ALU array convention.

Both read ports are combinational: changing a read address changes its output
without waiting for a clock. A write occurs only on a rising clock edge when
`write_en` is asserted. A read of the destination sees the old value before the
edge and the new value after the edge. Simulation initializes all entries to
zero. `ADDR_W` is an explicit parameter (default 3) because Verilog-2005 does
not provide `$clog2`; choose a width large enough to address all entries.

## Scalar file

`scalar_regfile` contains eight 32-bit registers. Its two processor read ports
and independent debug port are combinational. Writes occur on the rising edge
when enabled. Register `s0` always reads as zero, including on the debug port,
and writes to it are ignored.

The initial zero values are for simulation and may map to FPGA initialization
features depending on the target and synthesis flow.

## Verification

Run `make tb_regfiles`. The testbench keeps a shadow copy of every register,
checks every register through both normal read ports, tests disabled writes and
old/new read-during-write behavior, verifies `s0` and the debug port, and runs
2,000 randomized cycles for each file.

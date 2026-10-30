#!/bin/bash
# Run from the 02-uart-design folder: ./sim/run.sh
set -e
mkdir -p sim/out
iverilog -g2012 -o sim/out/uart_sim rtl/*.v tb/tb_uart_loopback_states.sv
vvp sim/out/uart_sim | tee sim/uart_sim_log.txt
mv uart_states.vcd sim/out/ 2>/dev/null || true
echo "Waveform generated at sim/out/uart_states.vcd (open with any VCD waveform viewer)"

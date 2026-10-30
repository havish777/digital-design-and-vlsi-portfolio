#!/bin/bash
# Run from the 01-mips-pipelined-processor folder: ./sim/run.sh
set -e
mkdir -p build sim/out
iverilog -g2012 -o sim/out/check_sim rtl/*.v tb/Proctb_check.v
vvp sim/out/check_sim | tee sim/check_log.txt
iverilog -g2012 -o sim/out/wave_sim rtl/*.v tb/Proctb.v
vvp sim/out/wave_sim > /dev/null
echo "Waveform generated at build/Proctb.vcd (open with any VCD waveform viewer)"

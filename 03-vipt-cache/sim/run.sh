#!/bin/bash
# Run from the 03-vipt-cache folder: ./sim/run.sh
set -e
mkdir -p sim/out
iverilog -g2012 -o sim/out/vipt_sim rtl/*.v tb/tb_vipt_cache.v
vvp sim/out/vipt_sim | tee sim/vipt_sim_log.txt
mv vipt_cache.vcd sim/out/ 2>/dev/null || true
echo "Waveform generated at sim/out/vipt_cache.vcd (open with any VCD waveform viewer)"

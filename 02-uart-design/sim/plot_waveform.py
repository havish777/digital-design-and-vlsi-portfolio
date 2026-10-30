"""Render key signals from sim/out/uart_states.vcd into docs/waveform_0xA5.png (first byte)."""
import re, sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

vcd = sys.argv[1] if len(sys.argv) > 1 else "sim/out/uart_states.vcd"
want = {"clk","rst","tx_start","tx_busy","serial","baud_tick","rx_done","data_in","data_out"}
ids, vals, scope = {}, {}, []
t = 0
with open(vcd) as f:
    for line in f:
        s = line.strip()
        if s.startswith("$scope"): scope.append(s.split()[2])
        elif s.startswith("$upscope"): scope.pop()
        elif s.startswith("$var"):
            p = s.split(); name = p[4]
            if len(scope) == 1 and name in want:   # top-level tb signals only
                ids[p[3]] = (name, int(p[2])); vals[name] = []
        elif s.startswith("#"): t = int(s[1:])
        elif s and s[0] in "01xz" and s[1:] in ids:
            vals[ids[s[1:]][0]].append((t, int(s[0])))
        elif s.startswith("b"):
            v, i = s[1:].split()
            if i in ids: vals[ids[i][0]].append((t, int(v, 2) if set(v) <= {"0","1"} else 0))

t0, t1 = 0, 1830   # first byte (0xA5) incl. start/stop, ns
order = ["clk","baud_tick","tx_start","tx_busy","serial","rx_done","data_in","data_out"]
fig, axes = plt.subplots(len(order), 1, figsize=(13, 7), sharex=True)
for ax, n in zip(axes, order):
    d = vals[n]; xs, ys = [], []
    for i, (tt, v) in enumerate(d):
        if tt > t1: break
        if xs: xs.append(tt); ys.append(ys[-1])
        xs.append(tt); ys.append(v)
    xs.append(t1); ys.append(ys[-1])
    ax.step(xs, ys, where="post", lw=1.2, color="#1f77b4")
    ax.set_ylabel(n, rotation=0, ha="right", va="center", fontsize=9)
    ax.set_yticks([]); ax.set_xlim(t0, t1)
    if n in ("data_in","data_out"):
        cur = [v for tt, v in d if tt <= (900 if n=="data_in" else 1825)][-1]
        ax.text(1000 if n=="data_in" else 1700, 0.5*max(ys), f"0x{cur:02X}", ha="center", va="center", fontsize=10, color="k")
    if n == "serial":
        for lbl, x in zip(["START","D0=1","D1=0","D2=1","D3=0","D4=0","D5=1","D6=0","D7=1","STOP"],
                          [285,445,605,765,925,1085,1245,1405,1565,1725]):
            ax.text(x, 0.5, lbl, ha="center", va="center", fontsize=7, color="crimson")
axes[-1].set_xlabel("time (ns)")
fig.suptitle("UART loopback - transmitting 0xA5 (BAUD_DIV=16, 100 MHz, 8-N-1)")
plt.tight_layout(); plt.savefig("docs/waveform_0xA5.png", dpi=130)

"""Render key signals from sim/out/vipt_cache.vcd into docs/ PNGs.
   usage: python3 sim/plot_waveform.py [vcd]"""
import sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

vcd = sys.argv[1] if len(sys.argv) > 1 else "sim/out/vipt_cache.vcd"
want = ["clk","fetch_valid_i","fetch_va_i","fetch_ready_o","cache_miss_req_o",
        "cache_miss_resp_i","cache_data_valid_o","cache_data_o"]
ids, sig, scope, t = {}, {n: [] for n in want}, [], 0
width = {}
with open(vcd) as f:
    for line in f:
        s = line.strip()
        if s.startswith("$scope"): scope.append(s.split()[2])
        elif s.startswith("$upscope"): scope.pop()
        elif s.startswith("$var"):
            p = s.split()
            if scope == ["tb_vipt_cache"] and p[4] in want:
                ids[p[3]] = p[4]; width[p[4]] = int(p[2])
        elif s.startswith("#"): t = int(s[1:])
        elif s and s[0] in "01xz" and not s.startswith("b") and s[1:] in ids:
            sig[ids[s[1:]]].append((t, None if s[0] in "xz" else int(s[0])))
        elif s.startswith("b"):
            v, i = s[1:].split()
            if i in ids: sig[ids[i]].append((t, int(v, 2) if set(v) <= {"0","1"} else None))

def value_at(n, tt):
    v = None
    for a, b in sig[n]:
        if a <= tt: v = b
        else: break
    return v

def plot(t0, t1, title, out):
    fig, axes = plt.subplots(len(want), 1, figsize=(14, 7.5), sharex=True)
    for ax, n in zip(axes, want):
        d = [(a, b) for a, b in sig[n]]
        pts = [(t0, value_at(n, t0))] + [(a, b) for a, b in d if t0 < a <= t1]
        ax.set_yticks([]); ax.set_xlim(t0/1000, t1/1000)
        ax.set_ylabel(n, rotation=0, ha="right", va="center", fontsize=8)
        if width[n] == 1:
            xs, ys = [], []
            for i, (a, b) in enumerate(pts):
                if xs: xs.append(a/1000); ys.append(ys[-1])
                xs.append(a/1000); ys.append(0.5 if b is None else b)
            xs.append(t1/1000); ys.append(ys[-1])
            ax.step(xs, ys, where="post", lw=1.2, color="#1f77b4"); ax.set_ylim(-0.2, 1.3)
        else:
            for i, (a, b) in enumerate(pts):
                e = pts[i+1][0] if i+1 < len(pts) else t1
                ax.plot([a/1000, e/1000], [1, 1], color="#1f77b4", lw=1)
                ax.plot([a/1000, e/1000], [0, 0], color="#1f77b4", lw=1)
                ax.plot([a/1000, a/1000], [0, 1], color="#1f77b4", lw=1)
                if (e - a) > 9000:
                    lbl = "x" if b is None else ("0x%X" % b if n != "fetch_va_i" else "idx 0x%02X" % ((b >> 0) & 0xFF))
                    ax.text((a+e)/2000, 0.5, lbl, ha="center", va="center", fontsize=7)
            ax.set_ylim(-0.3, 1.3)
    axes[-1].set_xlabel("time (ns)"); fig.suptitle(title)
    plt.tight_layout(); plt.savefig(out, dpi=125); plt.close()

# window 1: first fetch_valid rise -> cold miss, refill, replay hit
first = next(a for a, b in sig["fetch_valid_i"] if b == 1)
plot(first - 15000, first + 130000, "VIPT cache: cold miss -> refill -> replayed hit", "docs/waveform_miss_refill_hit.png")
# window 2: longest run of fetch_valid_i high (back-to-back hits)
best, cur = (0, 0), None
for a, b in sig["fetch_valid_i"]:
    if b == 1: cur = a
    elif cur is not None:
        if a - cur > best[1] - best[0]: best = (cur, a)
        cur = None
plot(best[0] - 20000, best[1] + 50000, "VIPT cache: 8 back-to-back hits (1 result per cycle, 2-cycle latency)", "docs/waveform_back_to_back_hits.png")

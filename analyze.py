"""Kayıt CSV'sini özetler ve her sensörü ayrı panelde çizer.
Kullanım: .venv/bin/python analyze.py kayitlar/kayit_x.csv  -> kayit_x.png
"""
import sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

path = sys.argv[1]
rows = defaultdict(list)
for line in open(path):
    if line.startswith("#"):
        continue
    p = line.rstrip("\n").split(",")
    if len(p) < 3:
        continue  # yarım kalan son satır
    rows[p[1]].append([float(x) for x in [p[0]] + p[2:]])

t0 = min(r[0][0] for r in rows.values())
data = {}
for name, r in rows.items():
    w = min(map(len, r))
    a = np.array([x[:w] for x in r])
    a[:, 0] = (a[:, 0] - t0) / 1e9
    data[name.split(".")[-1]] = a

dur = max(a[-1, 0] for a in data.values())
print(f"süre: {dur:.1f} s, sensör: {len(data)}")
for n, a in sorted(data.items()):
    hz = len(a) / max(a[-1, 0] - a[0, 0], 1e-9)
    print(f"{n:40s} n={len(a):7d} {hz:6.1f}Hz dim={a.shape[1]-1:2d} "
          f"mean={np.round(a[:, 1:4].mean(0), 2)} std={np.round(a[:, 1:4].std(0), 2)}")

fig, axs = plt.subplots(len(data), 1, figsize=(16, 2.2 * len(data)), sharex=True)
for ax, (n, a) in zip(np.atleast_1d(axs), sorted(data.items())):
    for i in range(1, min(a.shape[1], 4)):
        ax.plot(a[:, 0], a[:, i], lw=0.7, label=f"v{i-1}")
    ax.set_ylabel(n, rotation=0, ha="right", fontsize=8)
    ax.grid(alpha=0.3)
ax.set_xlabel("saniye")
ax.set_xticks(np.arange(0, dur + 1, 10))
plt.tight_layout()
out = path.rsplit(".", 1)[0] + ".png"
plt.savefig(out, dpi=80)
print("grafik:", out)

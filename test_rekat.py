import os, sys
if not os.path.isdir("kayitlar"):
    sys.exit("skip: kayitlar/ not found (personal recordings are not in the repo)")

# Recording 1: 4 rakats, start ~15 s, end ~264 s (read from the plot)
from rekat import analiz, bolumler, gravity

r = analiz(bolumler(gravity("kayitlar/kayit_20261123_153651.csv")))
assert (r["rekat"], r["ruku"], r["secde"]) == (4, 4, 8), r
assert 13 <= r["baslangic"] <= 18 and 260 <= r["bitis"] <= 268, r
print("ok", r)

# Same as the live count on the watch (MainActivity.say): find the vibration times
from rekat import durus
g = gravity("kayitlar/kayit_20261123_153651.csv")
titresim, win, acc, run, run_bas, secde = [], None, [], ".", 0, True
for t, x, y, z in g:
    if not acc: win = t
    acc.append((x, y, z))
    if t - win < 0.5: continue
    d = durus(*[sum(v) / len(acc) for v in zip(*acc)]); acc = []
    if d != run: run, run_bas = d, win
    if d == "S" and t - run_bas >= 1: secde = True
    if d == "K" and t - run_bas >= 5 and secde: secde = False; titresim.append(round(t))
assert len(titresim) == 4, titresim
print("live vibration times (s):", titresim)

# Recording 2: 2 rakats, live count 2 (vibrations at 9.9 and 66 s)
r2 = analiz(bolumler(gravity("kayitlar/kayit_20261123_154602.csv")))
assert (r2["rekat"], r2["ruku"], r2["secde"]) == (2, 2, 4), r2
print("ok", r2)

# Recording 3: 4 rakats, live count 4 (vibrations at 8.9, 60.9, 123.8, 178.5 s)
r3 = analiz(bolumler(gravity("kayitlar/kayit_20261123_155455.csv")))
assert (r3["rekat"], r3["ruku"], r3["secde"]) == (4, 4, 8), r3
print("ok", r3)

# Recording 4: 3 rakats, live count 3
r4 = analiz(bolumler(gravity("kayitlar/kayit_20261123_160041.csv")))
assert (r4["rekat"], r4["secde"]) == (3, 6), r4
print("ok", r4)

# Recording 5: 4 rakats, live count 4 (vibrations at 8.0, 53.5, 112.2, 149.7 s)
r5 = analiz(bolumler(gravity("kayitlar/kayit_20261123_160606.csv")))
assert (r5["rekat"], r5["ruku"], r5["secde"]) == (4, 4, 8), r5
print("ok", r5)

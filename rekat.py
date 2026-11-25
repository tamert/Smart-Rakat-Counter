"""Kayıttan namaz başlangıç/bitiş ve rekat sayısını çıkarır (sadece gravity sensörü).
Kullanım: .venv/bin/python rekat.py kayitlar/kayit_x.csv
"""
import sys

import numpy as np

# Ayar düğmeleri: saat SOL bilekte, ilk kayıttan (2026-11-23) okunan gravity (x,y,z) değerleri.
# Kıyam (eller bağlı)  ~ ( 5.8, -5.6, -5.3)
# Rükû (kol aşağı)     ~ ( 9.5, -1.0, -1.5)
# Secde                ~ ( 6.5, -5.8,  4.5)
# Oturuş (el dizde)    ~ ( 2.3, -5.7,  7.6)
def durus(x, y, z):
    if z < -3 and 4 < x < 8: return "K"
    if x > 8.5: return "R"
    if z > 2 and x > 5: return "S"
    if z > 5 and x < 4.5: return "O"
    return "."

PENCERE = 0.5  # s
MIN_SURE = {"K": 5, "R": 1, "S": 1, "O": 1, ".": 3}  # kısa bölümler geçiş sayılır, uzun "." ayırıcıdır


def gravity(path):
    g = [[float(v) for v in [p[0]] + p[2:5]] for p in
         (l.split(",") for l in open(path) if not l.startswith("#"))
         if len(p) >= 5 and p[1] == "android.sensor.gravity"]
    g = np.array(g)
    g[:, 0] = (g[:, 0] - g[0, 0]) / 1e9
    return g


def bolumler(g):
    """[(durus, bas_s, bit_s)], kısa bölümler atılmış ve aynı duruşlar birleştirilmiş."""
    etiket = []
    for t in np.arange(0, g[-1, 0], PENCERE):
        m = (g[:, 0] >= t) & (g[:, 0] < t + PENCERE)
        etiket.append((durus(*g[m, 1:].mean(0)) if m.any() else ".", t))
    seg = []
    for d, t in etiket:
        if seg and seg[-1][0] == d: seg[-1][2] = t + PENCERE
        else: seg.append([d, t, t + PENCERE])
    seg = [s for s in seg if s[2] - s[1] >= MIN_SURE[s[0]]]
    out = []
    for s in seg:
        if out and out[-1][0] == s[0]: out[-1][2] = s[2]
        else: out.append(s)
    return out


def analiz(seg):
    kiyam = [s for s in seg if s[0] == "K"]
    if not kiyam: return None
    i = seg.index(kiyam[0])
    bas = seg[i - 1][2] if i else kiyam[0][1]  # tekbir: kıyamdan önceki duruşun bittiği an
    secde_sonu = [s for s in seg if s[0] == "S"][-1][2]
    son_oturus = next(s for s in seg if s[0] == "O" and s[1] >= secde_sonu - 2)
    ic = [s for s in seg if bas <= s[1] <= son_oturus[2]]
    return dict(baslangic=bas, bitis=son_oturus[2], rekat=len(kiyam),
                ruku=sum(s[0] == "R" for s in ic), secde=sum(s[0] == "S" for s in ic))


if __name__ == "__main__":
    seg = bolumler(gravity(sys.argv[1]))
    print(" ".join(f"{d}{b:.0f}-{e:.0f}" for d, b, e in seg))
    print(analiz(seg))

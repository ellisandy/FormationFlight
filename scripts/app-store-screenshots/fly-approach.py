#!/usr/bin/env python3
"""Start a simulated straight-line approach to the Rose Bowl that arrives EARLY_S seconds before TOT.
Usage: ff_route.py <UDID> <TOT HH:MM:SS> [early_seconds]"""
import math, subprocess, sys, datetime as dt

udid, tot_s = sys.argv[1], sys.argv[2]
early = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
A, B, V = (34.2000, -118.4200), (34.1613, -118.1676), 72.0

def hav(p, q):
    R = 6371000.0
    la1, lo1, la2, lo2 = map(math.radians, (*p, *q))
    a = math.sin((la2-la1)/2)**2 + math.cos(la1)*math.cos(la2)*math.sin((lo2-lo1)/2)**2
    return 2*R*math.asin(math.sqrt(a))

now = dt.datetime.now()
h, m, s = map(int, tot_s.split(":"))
tot = now.replace(hour=h, minute=m, second=s, microsecond=0)
remaining = (tot - now).total_seconds() - early - 1.0  # ~1 s for simctl startup
D = hav(A, B)
d = min(remaining * V, D)
f = 1 - d / D
start = (A[0] + (B[0]-A[0])*f, A[1] + (B[1]-A[1])*f)
print(f"remaining={remaining:.1f}s dist={d/1852:.2f}nm start={start[0]:.5f},{start[1]:.5f}")
subprocess.run(["xcrun", "simctl", "location", udid, "start", f"--speed={V}",
                f"{start[0]:.5f},{start[1]:.5f}", f"{B[0]},{B[1]}"], check=True)

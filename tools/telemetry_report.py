"""Aggregate TELEMETRY lines from bot logs. Usage: python3 tools/telemetry_report.py log1 log2 ..."""
import sys, json, collections
dmg = collections.Counter(); deaths = collections.Counter(); enc = collections.defaultdict(lambda: collections.Counter())
n = 0
for f in sys.argv[1:]:
    for line in open(f, errors="ignore"):
        if line.startswith("TELEMETRY "):
            t = json.loads(line[10:]); n += 1
            for k, v in t["damage"].items(): dmg[k] += v
            for d in t["deaths"]: deaths[d] += 1
            for k, v in t["encounters"].items():
                for kk in ("time", "damage", "deaths"): enc[k][kk] += v.get(kk, 0)
print(f"runs: {n}")
print("\n## Damage taken per source (avg per run)")
for k, v in dmg.most_common(): print(f"  {k:32s} {v / n:7.1f}")
print("\n## Death causes (total)")
for k, v in deaths.most_common(): print(f"  {k:32s} {v}")
print("\n## Encounters (avg per run)")
for k in sorted(enc, key=lambda k: -enc[k]["damage"]):
    e = enc[k]; print(f"  {k:18s} time {e['time'] / n:6.1f}s  damage {e['damage'] / n:6.1f}  deaths {e['deaths'] / n:4.2f}")

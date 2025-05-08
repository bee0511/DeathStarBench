#!/usr/bin/env python3
"""
lat_box.py  – compare mean / p90 / p99 latencies across multiple wrk2‑HDR files
            each input file = one algorithm run (rr, po2, prequal …)

usage:  python lat_box.py  hdrfile1 hdrfile2 hdrfile3 ... \
            [--output FIG.png] [--units ms|us|ns] [--title "…"]

The script prints a short table on stdout and writes the plot.
"""
import argparse, re, sys, pathlib
from collections import defaultdict

import pandas as pd
import matplotlib.pyplot as plt

# ── regex helpers ──────────────────────────────────────────────────────────────
RE_LINE          = re.compile(r'\s+([\d.]+)\s+([\d.]+)\s+\d+\s+[\d.]+')
RE_MEAN_STDDEV   = re.compile(r'#\[Mean\s*=\s*([\d.]+)')
RE_PREFIX        = re.compile(r'^(rr|po2|prequal)_', re.I)

# ── parsing helpers ────────────────────────────────────────────────────────────
def percentile_latency(df: pd.DataFrame, pct: float) -> float:
    """first latency whose Percentile ≥ pct"""
    row = df[df['Percentile'] >= pct]
    return float(row.iloc[0]['Latency']) if not row.empty else float('nan')

def parse_file(path: str) -> dict:
    """return {'algo': 'Round Robin', 'mean': …, 'p90': …, 'p99': …}"""
    algo_raw = pathlib.Path(path).stem                # e.g. rr_run1
    m = RE_PREFIX.match(algo_raw)
    mapping = {'rr': 'Round Robin',
               'po2': 'Power of Two Choices',
               'prequal': 'Prequal'}
    algo = mapping.get(m.group(1).lower(), algo_raw) if m else algo_raw

    # --- latencies dataframe ---
    rows = [RE_LINE.match(l) for l in open(path) if RE_LINE.match(l)]
    rows = [(float(m.group(1)), float(m.group(2))) for m in rows]
    df = pd.DataFrame(rows, columns=['Latency', 'Percentile'])

    # --- mean from footer ---
    mean_line = next(l for l in open(path) if RE_MEAN_STDDEV.match(l))
    mean_val  = float(RE_MEAN_STDDEV.search(mean_line).group(1))

    return {'algo': algo,
            'mean': mean_val,
            'p90':  percentile_latency(df, 0.90),
            'p99':  percentile_latency(df, 0.99)}

# ── plotting ------------------------------------------------------------------
def make_plot(data, units, title, outfile):
    """
    data  =  [{'algo':'Round Robin', 'mean':…, 'p90':…, 'p99':…}, …]
    """
    grouped = defaultdict(list)
    for d in data:
        grouped[d['algo']].extend([d['mean'], d['p90'], d['p99']])

    algos  = list(grouped.keys())
    series = [grouped[a] for a in algos]      # each item length = 3

    fig, ax = plt.subplots(figsize=(8, 5))
    bp = ax.boxplot(series, vert=True, patch_artist=True,
                    labels=algos, showmeans=True, meanline=True)

    ax.set_ylabel(f'Latency ({units})')
    ax.set_title(title if title else 'Latency comparison (mean / p90 / p99)')
    ax.grid(True, axis='y', linestyle=':', alpha=.4)

    # nicer colours
    colours = ['#8da0cb', '#fc8d62', '#66c2a5', '#e78ac3']
    for patch, col in zip(bp['boxes'], colours*10):
        patch.set_facecolor(col)

    fig.tight_layout()
    fig.savefig(outfile, dpi=150)
    print(f'[+] wrote plot to {outfile}')


# ── CLI -----------------------------------------------------------------------
def cli():
    p = argparse.ArgumentParser(description='Box‑plot mean / p90 / p99 latency')
    p.add_argument('files', nargs='+', help='wrk2 HDR output files')
    p.add_argument('--output', '-o', default='lat_box.png')
    p.add_argument('--title', default='')
    p.add_argument('--units', default='ms', choices=['ns', 'us', 'ms'])
    return p.parse_args()

# ── main ----------------------------------------------------------------------
def main():
    args = cli()
    # --- existing code ---
    results = [parse_file(f) for f in args.files]

    def pct_delta(baseline, challenger):
        """positive => challenger is faster (= lower latency)"""
        return (baseline - challenger) / baseline * 100.0

    # locate the Prequal record
    preq = next((r for r in results if r['algo'].lower().startswith('prequal')), None)
    if preq:
        print('\nΔ Latency versus **Prequal** (positive = Prequal faster)')
        hdr =      'algo'.ljust(20) + 'mean%   p90%    p99%'
        print(hdr + '\n' + '-'*len(hdr))
        for r in results:
            if r is preq:
                continue
            d_mean = pct_delta(r['mean'] , preq['mean'])
            d_p90  = pct_delta(r['p90'],  preq['p90'])
            d_p99  = pct_delta(r['p99'],  preq['p99'])
            print(f"{r['algo']:<20s}{d_mean:6.1f}% {d_p90:7.1f}% {d_p99:7.1f}%")
    else:
        print("\n[!] No Prequal run detected ‑‑ cannot compute deltas.")

    print('\nLatency summary')
    print('algo,  mean,  p90,  p99')
    for r in results:
        print(f"{r['algo']:20s} {r['mean']:8.2f} {r['p90']:8.2f} {r['p99']:8.2f}")

    make_plot(results, args.units, args.title, args.output)



if __name__ == '__main__':
    main()

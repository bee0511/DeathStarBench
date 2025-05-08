#!/usr/bin/env python3
# k6_latency_plot.py
#
# Parse k6 JSON‑lines output, extract http_req_duration samples,
# draw a CDF and print median / p90 / p99 / max for each LB policy.
# ------------------------------------------------------------------

import argparse, json, pathlib, sys
import numpy as np
import matplotlib.pyplot as plt

NAME_MAP = {
    'rr'      : 'Round Robin',
    'po2'     : 'Power of Two Choices',
    'prequal' : 'Prequal'
}

def load_latencies(fname: pathlib.Path) -> np.ndarray:
    """Return all http_req_duration samples (ms) from a k6 JSONL file."""
    vals = []
    with fname.open() as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue                              # skip broken lines

            if rec.get('metric') != 'http_req_duration':
                continue                              # other metric -> ignore

            data = rec.get('data', {})
            if isinstance(data, dict) and 'value' in data:   # only Point rows
                vals.append(float(data['value']))
    if not vals:
        sys.exit(f'No http_req_duration Point samples found in {fname}')
    return np.array(vals, dtype=float)


def cdf_points(samples: np.ndarray):
    """Return (sorted_vals, cumulative_percentages)."""
    x = np.sort(samples)
    p = 100. * np.arange(len(x)) / (len(x) - 1)
    return x, p

def pretty_label(stem):
    key = stem.split('_',1)[0].lower()
    return NAME_MAP.get(key, stem)

# ---------- main -------------------------------------------------------------

ap = argparse.ArgumentParser(
        description="Plot k6 http_req_duration CDF for several LB outputs")
ap.add_argument('files', nargs='+', help='k6 JSON‑lines result files')
ap.add_argument('--output', default='k6_latency.png')
ap.add_argument('--title',  default='1000 RPS from k6 across Social Network with 4 backend servers')
args = ap.parse_args()

plt.figure(figsize=(8,4.5))
props  = dict(boxstyle='round', facecolor='lightcyan', alpha=0.5)
info   = []        # to build the text box later

for path_str in args.files:
    path   = pathlib.Path(path_str)
    data   = load_latencies(path)
    x, pct = cdf_points(data)

    label  = pretty_label(path.stem)
    plt.plot(x, pct, label=label)

    info.append(f"""{label:24s}
median  = {np.median(data):7.2f} ms
p90     = {np.percentile(data, 90):7.2f} ms
p99     = {np.percentile(data, 99):7.2f} ms
max     = {data.max():7.2f} ms
""")

# ----- figure cosmetics ------------------------------------------------------
plt.xlabel('Latency (ms)')
plt.ylabel('Cumulative percentage')
plt.yticks([50, 90, 99], ['50 %', '90 %', '99 %'])
plt.ylim([0,100])
plt.xlim([2, 8])
plt.grid(True, which='both', linestyle='--', alpha=0.4)
plt.legend()

plt.title(args.title, wrap=True)

# summary box (right‑hand side)
plt.text(1.02, 0.02, '\n'.join(info),
         transform=plt.gca().transAxes, fontsize=8,
         verticalalignment='bottom', bbox=props,
         fontfamily='monospace')

plt.tight_layout()
plt.savefig(args.output, dpi=300)
print(f'Wrote {args.output}')

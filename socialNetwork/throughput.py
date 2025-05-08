#!/usr/bin/env python3
# full_throughput_compare.py
#
# Parse wrk2 outputs and plot
#   – absolute Req/s
#   – Δ% vs Round‑Robin
#   – Δ% vs Power‑of‑Two‑Choices
#
# USAGE
#   python full_throughput_compare.py rr.txt po2.txt prequal.txt \
#       --title "Throughput – 1 000 RPS" --out throughput.png
# ---------------------------------------------------------------------------

import re, argparse, pathlib, sys
import matplotlib.pyplot as plt
import numpy as np

# ---------- parsing helpers -------------------------------------------------
REQ_RE = re.compile(r'Requests/sec:\s+([0-9.]+)')
LABEL_MAP = {'rr': 'Round‑Robin',
             'po2': 'Power‑of‑Two Choices',
             'prequal': 'Prequal'}

def pretty(stem):
    key = stem.split('_', 1)[0].lower()
    return LABEL_MAP.get(key, stem)

def req_per_sec(path: pathlib.Path) -> float:
    with path.open() as fh:
        for line in fh:
            m = REQ_RE.search(line)
            if m:
                return float(m.group(1))
    sys.exit(f'[ERR] Requests/sec not found in {path}')

# ---------- plotting helpers -----------------------------------------------
def add_labels(ax, bars, color):
    for bar in bars:
        val = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, val,
                f'{val:.0f}', ha='center', va='bottom',
                fontsize=8, color=color)

def delta_percent(values, base_idx):
    base = values[base_idx]
    return [((v-base)/base*100) if base else 0 for v in values]

# ---------- main script -----------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description='Plot absolute throughput + Δ% vs RR & Po2')
    ap.add_argument('files', nargs='+', help='wrk2 output files')
    ap.add_argument('--title', default='')
    ap.add_argument('--out', default='throughput.png')
    args = ap.parse_args()

    labels, reqs = [], []
    for f in args.files:
        p = pathlib.Path(f)
        labels.append(pretty(p.stem))
        reqs.append(req_per_sec(p))
        print(f'Parsed {p}: {reqs[-1]:.1f} req/s')

    # ----- figure layout ----------------------------------------------------
    # col_n = 1 + ('Round‑Robin' in labels) + ('Power‑of‑2 Choices' in labels)
    col_n = 1
    fig, axes = plt.subplots(1, col_n, figsize=(4*col_n, 4.2), sharex=False)
    if col_n == 1:             # always iterable
        axes = [axes]

    # -- left: absolute ------------------------------------------------------
    ax_abs = axes[0]
    x = np.arange(len(labels))
    bars = ax_abs.bar(x, reqs, color='#4e79a7')
    add_labels(ax_abs, bars, '#4e79a7')
    ax_abs.set_xticks(x)
    ax_abs.set_xticklabels(labels, rotation=0)
    # make x-axis labels smaller
    for label in ax_abs.get_xticklabels():
        label.set_fontsize(8)
    ax_abs.set_ylabel('Requests / s')
    ax_abs.set_title('Absolute throughput')
    # zoom y‑axis around data (2 % margin)
    ymin, ymax = min(reqs)*0.98, max(reqs)*1.02
    ax_abs.set_ylim([ymin, ymax])

    col = 1
    # # -- centre: Δ vs RR -----------------------------------------------------
    # if 'Round‑Robin' in labels:
    #     idx = labels.index('Round‑Robin')
    #     deltas = delta_percent(reqs, idx)
    #     ax = axes[col]
    #     bars = ax.bar(x, deltas, color='#59a14f')
    #     add_labels(ax, bars, '#59a14f')
    #     ax.axhline(0, color='gray', lw=0.8)
    #     ax.set_xticks(x); ax.set_xticklabels(labels, rotation=0)
    #     ax.set_ylabel('% vs RR')
    #     ax.set_title('Δ throughput vs Round‑Robin')
    #     col += 1

    # # -- right: Δ vs Po2 -----------------------------------------------------
    # if 'Power‑of‑2 Choices' in labels:
    #     idx = labels.index('Power‑of‑2 Choices')
    #     deltas = delta_percent(reqs, idx)
    #     ax = axes[col]
    #     bars = ax.bar(x, deltas, color='#e15759')
    #     add_labels(ax, bars, '#e15759')
    #     ax.axhline(0, color='gray', lw=0.8)
    #     ax.set_xticks(x); ax.set_xticklabels(labels, rotation=0)
    #     ax.set_ylabel('% vs Po2')
    #     ax.set_title('Δ throughput vs Po2')

    if args.title:
        fig.suptitle(args.title, y=1.02, fontsize=12)

    plt.tight_layout()
    plt.savefig(args.out, dpi=300, bbox_inches='tight')
    print(f'Wrote {args.out}')

if __name__ == '__main__':
    main()

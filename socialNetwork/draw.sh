#!/bin/sh

THREAD_COUNT=8
CONNECTION_COUNT=50
DURATION=300s
REQUEST_RATE=50

python hdr-plot.py \
    results/rr_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}.log \
    results/po2_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}.log \
    results/prequal_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}.log \
    --output results/c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}.png \
    --title "Social Network Load Balancing Test" \
    --xmax 5
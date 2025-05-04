#!/bin/bash
# This script is used to run the social network test using wrk2

THREAD_COUNT=8
CONNECTION_COUNT=1000
DURATION=300s
REQUEST_RATE=1000
BACKEND_NUM=4
RESULTS_DIR="results"
mkdir -p $RESULTS_DIR

# For Prequal load balancing
# echo "Running Prequal load balancing test..."
# wrk -t$THREAD_COUNT -c$CONNECTION_COUNT -d$DURATION -L -s ./wrk2/scripts/social-network/compose-post.lua \
#     http://localhost:20003/wrk2-api/post/compose -R$REQUEST_RATE > $RESULTS_DIR/prequal_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log

# echo "Prequal load balancing test completed."

# sleep 30

# # For power of two load balancing
# echo "Running power of two load balancing test..."
# wrk -t$THREAD_COUNT -c$CONNECTION_COUNT -d$DURATION -L -s ./wrk2/scripts/social-network/compose-post.lua \
#     http://localhost:20002/wrk2-api/post/compose -R$REQUEST_RATE > $RESULTS_DIR/po2_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log
# echo "Power of two load balancing test completed."

# sleep 30

# # For round-robin load balancing
# echo "Running round-robin load balancing test..."
# wrk -t$THREAD_COUNT -c$CONNECTION_COUNT -d$DURATION -L -s ./wrk2/scripts/social-network/compose-post.lua \
#     http://localhost:20001/wrk2-api/post/compose -R$REQUEST_RATE > $RESULTS_DIR/rr_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log

# echo "Round-robin load balancing test completed."

# Draw the results
python hdr-plot.py \
    results/rr_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log \
    results/po2_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log \
    results/prequal_c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.log \
    --output results/c${CONNECTION_COUNT}_d${DURATION}_r${REQUEST_RATE}_b${BACKEND_NUM}.png \
    --title "Social Network Load Balancing Test" \
    --xmax 400
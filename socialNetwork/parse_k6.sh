#/bin/sh

python parse_k6.py \
    rr_8_4000.json \
    po2_8_4000.json \
    prequal_8_4000.json \
    --out 8backend_k6_4000.png \
    --title "4000 RPS from k6 across Social Network with 8 backend servers"
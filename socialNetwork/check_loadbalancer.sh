#/bin/bash

sudo docker logs $(sudo docker ps | grep load-balancer | awk '{print $1}')
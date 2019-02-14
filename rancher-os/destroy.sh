#!/usr/bin/env bash

for machine in `docker-machine ls | grep rancher | awk '{print $1}'`
do
    docker-machine rm $machine
done

[ "$COMPOSE_DOWN" == "true" ] && docker-compose rm -fs

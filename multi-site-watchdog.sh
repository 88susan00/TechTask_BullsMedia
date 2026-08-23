#!/usr/bin/env bash

sites=(
  "site1 http://localhost/site1/healthz"
  "site2 http://localhost/site2/healthz"
  "site3 http://localhost/site3/healthz"
)

while true; do
    for entry in "${sites[@]}"; do

        read -r container url <<< "$entry"

        if curl -fsS --max-time 5 "$url" > /dev/null 2>&1; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $container is healthy"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $container is DOWN, starting..."
            docker compose up -d "$container"
            sleep 15
        fi

    done

    sleep 10
done

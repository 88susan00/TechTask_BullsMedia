#!/bin/bash

# Список сервісів
services=("proxy" "site1" "site2" "site3")

while true; do
  for service in "${services[@]}"; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "techtask_bullsmedia-${service}-1" 2>/dev/null)

    if [ "$status" != "healthy" ]; then
      echo "$(date) - $service unhealthy ($status). Restarting..."
      docker compose up -d "$service"
    else
      echo "$(date) - $service healthy"
    fi
  done
  sleep 30
done


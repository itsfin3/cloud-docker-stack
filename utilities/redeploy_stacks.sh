#!/bin/bash

BASE_DIR=/srv/docker # Specify the parent dir where you have moved the compose files

STACKS=(
  hobby/minecraft
  hobby/nginx
  monitoring/grafana
  monitoring/prometheus
  server-management/portainer
  server-management/wg-easy
)

for stack in "${STACKS[@]}"; do
  echo "Redeploying $stack..."
  docker compose -f "$BASE_DIR/$stack/docker-compose.yml" pull
  docker compose -f "$BASE_DIR/$stack/docker-compose.yml" up -d --force-recreate
done

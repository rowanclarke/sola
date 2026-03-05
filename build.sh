#!/usr/bin/env bash

CONTAINER="flutter-cargokit"

case "$1" in
  reset)
    docker compose down; docker compose up -d
    ;;
  gen)
    docker exec -it "$CONTAINER" sh -c "cd rust && dart run ffigen --config ffigen.yaml"
    ;;
  run)
    docker exec -it "$CONTAINER" flutter run --vm-service-port=3001
    ;;
  connect)
    docker exec -it "$CONTAINER" adb devices
    ;;
  serve)
    docker exec -it "$CONTAINER" socat TCP-LISTEN:3000,fork,reuseaddr TCP:127.0.0.1:3001 &
    ;;
  *)
    echo "Usage: $0 {gen|run|connect|serve}"
    exit 1
    ;;
esac

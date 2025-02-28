#!/bin/bash

# Stop all containers
echo "Stopping all containers..."
cd $(dirname $0)
docker compose down

echo "All containers stopped!" 
#!/bin/bash

# Change to the script's directory
cd $(dirname $0)
cd ..

# Create dev.envrc file if it doesn't exist
if [ ! -f dev.envrc ]; then
  echo "Creating dev.envrc file..."
  cp dev.envrc.example dev.envrc 2>/dev/null || echo "# Development environment variables" > dev.envrc
  echo "dev.envrc file created. You may want to edit it with your custom settings."
fi

# Create dev.override.envrc file for Docker if it doesn't exist
if [ ! -f dev.override.envrc ]; then
  echo "Creating dev.override.envrc file for Docker..."
  cat > dev.override.envrc << EOF
# Docker-specific settings
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
EOF
  echo "dev.override.envrc file created for Docker."
fi

# Export environment variables from dev.override.envrc
if [ -f dev.override.envrc ]; then
  echo "Loading environment variables from dev.override.envrc..."
  export $(grep -v '^#' dev.override.envrc | xargs)
fi

# Go back to the lux_app directory
cd lux_app

# Print PostgreSQL port for debugging
echo "Using PostgreSQL port: ${POSTGRES_PORT:-5432}"

# Check if port is already in use
PORT=${POSTGRES_PORT:-5432}
if command -v nc &> /dev/null; then
  if nc -z localhost $PORT &> /dev/null; then
    echo "Error: Port $PORT is already in use."
    echo "To use a different port, add POSTGRES_PORT=5433 (or another free port) to your dev.override.envrc file."
    echo "Then update your database configuration to use the same port."
    exit 1
  fi
elif command -v lsof &> /dev/null; then
  if lsof -i :$PORT &> /dev/null; then
    echo "Error: Port $PORT is already in use."
    echo "To use a different port, add POSTGRES_PORT=5433 (or another free port) to your dev.override.envrc file."
    echo "Then update your database configuration to use the same port."
    exit 1
  fi
fi

# Start PostgreSQL container
echo "Starting PostgreSQL container..."
docker compose up -d postgres || {
  echo "Error: Failed to start PostgreSQL container."
  echo "This could be due to port conflicts or other Docker issues."
  echo "Check the Docker logs for more details: docker compose logs postgres"
  exit 1
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0
while ! docker compose exec postgres pg_isready -U postgres > /dev/null 2>&1; do
  echo -n "."
  sleep 1
  attempt=$((attempt+1))
  if [ $attempt -ge $max_attempts ]; then
    echo " Timed out waiting for PostgreSQL to be ready!"
    echo "Check the container logs with: docker compose logs postgres"
    exit 1
  fi
done
echo " PostgreSQL is ready!"

# Create and migrate database
echo "Setting up the database..."
mix deps.get
mix ecto.create
mix ecto.migrate

echo "Database setup complete!"
echo "You can now start the Phoenix server with: mix phx.server"
echo "Or run it in interactive mode with: iex -S mix phx.server" 
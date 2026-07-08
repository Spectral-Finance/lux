# LuxApp

## Setup Options

### Option 1: Using Docker (Recommended)

This project includes Docker configuration for easy setup and consistent development environments.

#### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) (Docker Compose is included with Docker Desktop installations)

#### Getting Started with Docker

1. Make the setup scripts executable:
   ```bash
   chmod +x lux_app/docker-start.sh lux_app/docker-stop.sh
   ```

2. Start the PostgreSQL database:
   ```bash
   cd lux_app && ./docker-start.sh
   ```
   This script will:
   - Start a PostgreSQL container
   - Create necessary environment files
   - Wait for the database to be ready
   - Create and migrate the database

3. Start the Phoenix server:
   ```bash
   cd lux_app && mix phx.server
   ```
   Or run it in interactive mode:
   ```bash
   cd lux_app && iex -S mix phx.server
   ```

4. To stop all containers when you're done:
   ```bash
   cd lux_app && ./docker-stop.sh
   ```

### Option 2: Manual Setup

To start your Phoenix server without Docker:

1. Ensure you have PostgreSQL installed and running locally
2. Copy the example environment file:
   ```bash
   cp dev.envrc.example dev.envrc
   ```
3. Run `cd lux_app && mix deps.get` to install dependencies
4. Create and migrate your database with `cd lux_app && mix ecto.setup`
5. Start Phoenix endpoint with `cd lux_app && mix phx.server` or inside IEx with `cd lux_app && iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Environment Configuration

This project uses [dotenvy](https://hexdocs.pm/dotenvy/Dotenvy.html) for environment variable management. The following files are used:

- `dev.envrc` - Base environment variables for development
- `dev.override.envrc` - Local development overrides (not committed to git)
- `test.envrc` - Test environment variables
- `test.override.envrc` - Test environment overrides (not committed to git)

## Development

### Database Management

- Create database: `mix ecto.create`
- Run migrations: `mix ecto.migrate`
- Reset database: `mix ecto.reset`

### Testing

Run tests with:
```bash
mix test
```

### Static Analysis with Dialyzer

This project uses [Dialyxir](https://github.com/jeremyjh/dialyxir), a mix tasks wrapper for Dialyzer, to perform static code analysis and type checking.

#### Building the PLT files

Before running Dialyzer for the first time, you need to build the Persistent Lookup Table (PLT) files:

```bash
mix dialyzer --plt
```

This process may take several minutes to complete as it analyzes all dependencies.

#### Running Dialyzer

To run Dialyzer and check for type inconsistencies:

```bash
mix dialyzer
```

Or use the shorter format:

```bash
mix dialyzer --format short
```

You can also use the alias:

```bash
mix dialyzer
```

#### Adding Type Specifications

To get the most out of Dialyzer, add type specifications to your functions using `@spec`. For example:

```elixir
@spec add(integer(), integer()) :: integer()
def add(a, b), do: a + b
```

## Production

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

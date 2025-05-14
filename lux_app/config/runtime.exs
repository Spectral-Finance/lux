import Config
import Dotenvy

# Load environment variables from .envrc files
if config_env() == :test do
  source([
    "../test.envrc",
    "../test.override.envrc"
  ])
else
  # Initialize an empty sources list
  sources = []

  # Add base .envrc file if it exists
  base_file = "../#{config_env()}.envrc"
  sources = if File.exists?(base_file), do: sources ++ [base_file], else: sources

  # Add override .envrc file if it exists
  override_file = "../#{config_env()}.override.envrc"
  sources = if File.exists?(override_file), do: sources ++ [override_file], else: sources

  # Add MIX_ENV_FILE if it exists
  mix_env_file = System.get_env("MIX_ENV_FILE")

  sources =
    if mix_env_file && File.exists?(mix_env_file), do: sources ++ [mix_env_file], else: sources

  # Load from sources and then from system env
  source(sources ++ [System.get_env()])
end

config :lux_app, env: config_env()

# Configure database based on environment variables in development
if config_env() == :dev or config_env() == :test do
  config :lux_app, LuxApp.Repo,
    username: env!("POSTGRES_USER", :string, "postgres"),
    password: env!("POSTGRES_PASSWORD", :string, "postgres"),
    hostname: env!("POSTGRES_HOST", :string, "localhost"),
    database: env!("POSTGRES_DB", :string, "lux_app_dev"),
    port: env!("POSTGRES_PORT", :integer, 5432)

  # Configure endpoint
  if port = env!("PORT", :integer, nil) do
    config :lux_app, LuxAppWeb.Endpoint, http: [port: port]
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/lux_app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if env!("PHX_SERVER", :boolean, false) do
  config :lux_app, LuxAppWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    env!("DATABASE_URL", :string, nil) ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if env!("ECTO_IPV6", :boolean, false), do: [:inet6], else: []

  config :lux_app, LuxApp.Repo,
    # ssl: true,
    url: database_url,
    pool_size: env!("POOL_SIZE", :integer, 10),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env!("SECRET_KEY_BASE", :string, nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = env!("PHX_HOST", :string, "example.com")
  port = env!("PORT", :integer, 4000)

  config :lux_app, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string, nil)

  config :lux_app, LuxAppWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :lux_app, LuxAppWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :lux_app, LuxAppWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :lux_app, LuxApp.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

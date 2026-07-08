defmodule Lux.Integrations.Allora do
  @moduledoc """
  Integration with the Allora API for accessing prediction markets and inference data.

  Allora is a decentralized prediction market platform that provides real-time price
  predictions and market insights through a network of specialized prediction workers.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Allora,
        base_url: System.get_env("ALLORA_BASE_URL") || "https://api.upshot.xyz/v2",
        chain_slug: System.get_env("ALLORA_CHAIN_SLUG") || "testnet"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      ALLORA_API_KEY="your-api-key"
      ALLORA_BASE_URL="https://api.upshot.xyz/v2"  # Optional, defaults to this value
      ALLORA_CHAIN_SLUG="testnet"                  # Optional, defaults to "testnet"

  ## Chain IDs

  The module supports different blockchain networks through chain slugs:
  - `"testnet"` -> `"11155111"` (Sepolia testnet)
  - `"mainnet"` -> `"1"` (Ethereum mainnet)

  ## Authentication

  Authentication is handled via API key in the `x-api-key` header. The key is fetched
  from the application configuration and validated before each request.

  ## Usage Examples

  ### Basic Setup

      # In your lens or module:
      alias Lux.Integrations.Allora

      # Get configured base URL
      base_url = Allora.base_url()  # => "https://api.upshot.xyz/v2"

      # Get chain ID for current network
      chain_id = Allora.chain_id()  # => "11155111" for testnet

      # Get authentication headers
      headers = Allora.headers()
      # => [
      #   {"Accept", "application/json"},
      #   {"Content-Type", "application/json"},
      #   {"x-api-key", "your-api-key"}
      # ]

  ### Using with Lenses

      defmodule MyApp.Lenses.AlloraExample do
        use Lux.Lens,
          name: "Allora Example",
          url: "\#{Allora.base_url()}/allora/\#{Allora.chain_id()}/topics",
          method: :get,
          headers: Allora.headers(),
          auth: Allora.auth()
      end

  ### Error Handling

  The module includes robust error handling for common scenarios:

      # API key validation
      Allora.api_key()  # Raises if ALLORA_API_KEY is not configured

      # Authentication
      headers = Allora.headers()
      authenticated = Allora.authenticate(headers)  # Adds x-api-key if not present

  ## Available Lenses

  The integration includes two main lenses:

  1. `Lux.Lenses.Allora.GetTopics` - Fetches all available prediction topics
     ```elixir
     {:ok, topics} = Lux.Lenses.Allora.GetTopics.focus(%{})
     # Returns list of topics with metadata, participation stats, and emissions data
     ```

  2. `Lux.Lenses.Allora.GetInference` - Fetches price predictions
     ```elixir
     # Get BTC price prediction
     {:ok, inference} = Lux.Lenses.Allora.GetInference.focus(%{
       asset: "BTC",
       timeframe: "5m",
       signature_format: "ethereum-11155111"
     })

     # Get prediction by topic ID
     {:ok, inference} = Lux.Lenses.Allora.GetInference.focus(%{
       topic_id: 123,
       signature_format: "ethereum-11155111"
     })
     ```

  ## Response Formats

  ### Topics Response
      %{
        topic_id: 1,
        topic_name: "BTC/USD",
        description: "Bitcoin price prediction",
        epoch_length: 300,              # 5 minutes
        ground_truth_lag: 60,           # 1 minute
        loss_method: "rmse",
        worker_submission_window: 60,    # 1 minute
        worker_count: 10,
        reputer_count: 3,
        total_staked_allo: 1000.0,
        total_emissions_allo: 100.0,
        is_active: true,
        updated_at: "2024-03-28T12:00:00Z"
      }

  ### Inference Response
      %{
        prediction: 65432.1,            # Predicted price
        confidence_interval: [65400.0, 65500.0],
        signature: "0x...",             # Cryptographic signature
        timestamp: "2024-03-28T12:00:00Z",
        metadata: %{
          asset: "BTC",
          timeframe: "5m",
          worker_count: 5,
          aggregation_method: "weighted_mean"
        }
      }
  """

  @type auth_type :: :custom
  @type chain_slug :: String.t()
  @type chain_id :: String.t()
  @type api_key :: String.t()
  @type headers :: [{String.t(), String.t()}]

  require Logger

  @doc """
  Gets the configured Allora base URL.
  Defaults to "https://api.upshot.xyz/v2" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.upshot.xyz/v2")
  end

  @doc """
  Gets the configured Allora chain slug.
  Defaults to "testnet" if not configured.
  """
  @spec chain_slug() :: String.t()
  def chain_slug do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:chain_slug, "testnet")
  end

  @doc """
  Gets the chain ID based on the configured chain slug.
  Returns "allora-testnet-1" for testnet and "allora-mainnet-1" for mainnet.
  """
  @spec chain_id() :: String.t()
  def chain_id do
    case chain_slug() do
      "mainnet" -> "allora-mainnet-1"
      _ -> "allora-testnet-1"
    end
  end

  @doc """
  Gets the default headers for Allora API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for Allora API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :api_key,
      key: &__MODULE__.api_key/0
    }
  end

  @doc """
  Authenticates a lens for Allora API requests.
  Only adds the x-api-key header if it's not already present.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-api-key" end) do
      nil ->
        %{lens | headers: [{"x-api-key", api_key()} | headers]}
      _ ->
        lens
    end
  end

  # Gets the Allora API key from configuration.
  # Raises if the key is not configured.
  @spec api_key() :: String.t()
  def api_key do
    :lux
    |> Application.get_env(__MODULE__)
    |> Keyword.get(:api_key)
  end
end

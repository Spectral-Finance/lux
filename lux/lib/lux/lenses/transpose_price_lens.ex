defmodule Lux.Lenses.TransposePriceLens do
  @moduledoc """
  Lens for fetching token prices from the Transpose API.

  ## Example

  ```
  alias Lux.Lenses.TransposePriceLens

  # Single token
  TransposePriceLens.focus(%{
    token_addresses: ["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"],  # UNI token
    timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  })

  # Multiple tokens
  TransposePriceLens.focus(%{
    token_addresses: [
      "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",  # UNI
      "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9"   # AAVE
    ],
    timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  })
  ```
  """

  use Lux.Lens,
    name: "Transpose Token Price API",
    description: "Fetches historical token prices from Transpose",
    url: "https://api.transpose.io/prices/price",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chain_id: %{
          type: :string,
          description: "Blockchain to query",
          default: "ethereum",
          enum: [
            "ethereum",
            "polygon",
            "optimism",
            "arbitrum",
            "canto",
            "base",
            "avalanche"
          ]
        },
        token_addresses: %{
          type: :array,
          description: "List of token contract addresses or ENS names (max 25)",
          items: %{
            type: :string,
            pattern: "^0x[a-fA-F0-9]{40}$"
          },
          maxItems: 25
        },
        timestamp: %{
          type: :string,
          description: "Timestamp in ISO-8601 format (YYYY-MM-DDTHH:MM:SS)",
          format: "date-time"
        }
      },
      required: ["token_addresses", "timestamp"]
    }

  def add_api_key(lens) do
    %{lens | headers: lens.headers ++ [{"X-API-KEY", Lux.Config.transpose_api_key()}]}
  end

  def before_focus(params) do
    # Convert token_addresses array to comma-separated string
    Map.update!(params, :token_addresses, &Enum.join(&1, ","))
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"prices" => [%{"price" => 5.20, "token_address" => "0x..."}]})
      {:ok, %{prices: [%{price: 5.20, token_address: "0x...", ...}]}}

      iex> after_focus(%{"error" => "Invalid API key"})
      {:error, "Invalid API key"}
  """
  @impl true
  def after_focus(%{"status" => "success", "results" => prices}) do
    transformed_prices =
      Enum.map(prices, fn price ->
        %{
          price: price["price"],
          token_address: price["token_address"],
          token_symbol: price["token_symbol"],
          timestamp: price["timestamp"],
          block_number: price["block_number"]
        }
      end)

    {:ok, %{prices: transformed_prices}}
  end

  @impl true
  def after_focus(%{"status" => "error", "message" => message}) do
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end

defmodule Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism do
  @moduledoc """
  A prism that fetches open orders from the Coinbase Exchange.

  ## Example

      # Get all open orders
      iex> Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{})
      {:ok,
       %{
         status: "success",
         orders: [
           %{
             "id" => "order_id_1",
             "product_id" => "BTC-USD",
             "side" => "buy",
             "type" => "limit",
             "status" => "open",
             "price" => "50000.00",
             "size" => "0.01"
           }
         ]
       }}

      # Get open orders for a specific product
      iex> Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{
      ...>   product_id: "BTC-USD"
      ...> })

      # Get orders by status
      iex> Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{
      ...>   status: "pending"
      ...> })

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase Open Orders",
    description: "Fetches open orders from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Filter by product ID (e.g., 'BTC-USD')"
        },
        status: %{
          type: :string,
          description: "Filter by order status",
          enum: ["open", "pending", "active", "done", "settled"]
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        orders: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              product_id: %{type: :string},
              side: %{type: :string, enum: ["buy", "sell"]},
              type: %{type: :string},
              status: %{type: :string},
              price: %{type: :string},
              size: %{type: :string},
              filled_size: %{type: :string},
              executed_value: %{type: :string},
              created_at: %{type: :string}
            }
          }
        },
        error: %{type: :string}
      },
      required: ["status", "orders"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, passphrase} <- get_passphrase(),
         {:ok, base_url} <- {:ok, Config.coinbase_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- fetch_orders(api_key, api_secret, passphrase, base_url, input) do
      {:ok, %{status: "success", orders: result}}
    else
      {:error, :missing_api_key} ->
        {:error, "Coinbase API key is not configured"}

      {:error, :missing_api_secret} ->
        {:error, "Coinbase API secret is not configured"}

      {:error, :missing_passphrase} ->
        {:error, "Coinbase API passphrase is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to fetch orders: #{inspect(reason)}"}
    end
  end

  defp get_api_key do
    {:ok, Config.coinbase_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    {:ok, Config.coinbase_api_secret()}
  rescue
    RuntimeError -> {:error, :missing_api_secret}
  end

  defp get_passphrase do
    {:ok, Config.coinbase_api_passphrase()}
  rescue
    RuntimeError -> {:error, :missing_passphrase}
  end

  defp fetch_orders(api_key, api_secret, passphrase, base_url, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               passphrase: passphrase,
               base_url: base_url,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import setup

        rest_client, _ = setup(api_key, api_secret, passphrase, base_url)

        product_id = params.get("product_id")
        status = params.get("status")

        try:
            orders = rest_client.get_orders(product_id=product_id, status=status)
            orders
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
    end
  end
end
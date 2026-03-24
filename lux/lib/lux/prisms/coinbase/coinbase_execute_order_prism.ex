defmodule Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism do
  @moduledoc """
  A prism that executes orders on the Coinbase Exchange.

  ## Example

      # Limit order
      iex> Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "buy",
      ...>   order_type: "limit",
      ...>   price: "50000.00",
      ...>   size: "0.01"
      ...> })
      {:ok,
       %{
         status: "success",
         order_result: %{
           "id" => "order_id_here",
           "product_id" => "BTC-USD",
           "side" => "buy",
           "type" => "limit",
           "status" => "open"
         }
       }}

      # Market order
      iex> Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
      ...>   product_id: "ETH-USD",
      ...>   side: "sell",
      ...>   order_type: "market",
      ...>   size: "0.5"
      ...> })

      # Stop order
      iex> Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "sell",
      ...>   order_type: "stop",
      ...>   price: "45000.00",
      ...>   stop_price: "46000.00",
      ...>   size: "0.01"
      ...> })

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase Order Execution",
    description: "Executes orders on Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair (e.g., 'BTC-USD', 'ETH-USD')"
        },
        side: %{
          type: :string,
          description: "Order side",
          enum: ["buy", "sell"]
        },
        order_type: %{
          type: :string,
          description: "Order type",
          enum: ["limit", "market", "stop", "stop_limit"]
        },
        price: %{
          type: :string,
          description: "Limit price (required for limit and stop_limit orders)"
        },
        size: %{
          type: :string,
          description: "Order size in base currency"
        },
        funds: %{
          type: :string,
          description: "Amount in quote currency (alternative to size for market orders)"
        },
        stop_price: %{
          type: :string,
          description: "Stop price for stop orders"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force",
          enum: ["GTC", "GTT", "IOC", "FOK", "GTD"],
          default: "GTC"
        },
        cancel_after: %{
          type: :string,
          description: "Cancel after duration (for GTT orders, e.g., 'min', 'hour', 'day')"
        },
        post_only: %{
          type: :boolean,
          description: "Post only order flag",
          default: false
        }
      },
      required: ["product_id", "side", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order_result: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            product_id: %{type: :string},
            side: %{type: :string},
            type: %{type: :string},
            status: %{type: :string},
            price: %{type: :string},
            size: %{type: :string},
            filled_size: %{type: :string},
            executed_value: %{type: :string}
          }
        },
        error: %{type: :string}
      },
      required: ["status"]
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
         {:ok, result} <- execute_order(api_key, api_secret, passphrase, base_url, input) do
      {:ok, %{status: "success", order_result: result}}
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
        {:error, "Failed to execute order: #{inspect(reason)}"}
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

  defp execute_order(api_key, api_secret, passphrase, base_url, params) do
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
        import json

        rest_client, _ = setup(api_key, api_secret, passphrase, base_url)

        # Build order parameters
        order = {
            "product_id": params["product_id"],
            "side": params["side"],
            "type": params["order_type"]
        }

        # Add optional parameters
        if "price" in params:
            order["price"] = params["price"]
        if "size" in params:
            order["size"] = params["size"]
        if "funds" in params:
            order["funds"] = params["funds"]
        if "stop_price" in params:
            order["stop_price"] = params["stop_price"]
        if "time_in_force" in params:
            order["time_in_force"] = params["time_in_force"]
        if "cancel_after" in params:
            order["cancel_after"] = params["cancel_after"]
        if "post_only" in params:
            order["post_only"] = params["post_only"]

        try:
            result = rest_client.place_order(order)
            result
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
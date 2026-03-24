defmodule Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism do
  @moduledoc """
  A prism that cancels orders on the Coinbase Exchange.

  ## Example

      # Cancel a specific order
      iex> Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
      ...>   order_id: "order_id_here"
      ...> })
      {:ok,
       %{
         status: "success",
         cancelled_order: %{
           "order_id" => "order_id_here"
         }
       }}

      # Cancel all orders for a product
      iex> Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
      ...>   cancel_all: true,
      ...>   product_id: "BTC-USD"
      ...> })

      # Cancel all orders
      iex> Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
      ...>   cancel_all: true
      ...> })

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase Order Cancellation",
    description: "Cancels orders on Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Order ID to cancel (required if cancel_all is false)"
        },
        cancel_all: %{
          type: :boolean,
          description: "Cancel all orders",
          default: false
        },
        product_id: %{
          type: :string,
          description: "Product ID to filter orders when cancel_all is true"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        cancelled_orders: %{
          type: :array,
          items: %{type: :string},
          description: "List of cancelled order IDs"
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
         {:ok, result} <- cancel_order(api_key, api_secret, passphrase, base_url, input) do
      {:ok, %{status: "success", cancelled_orders: result}}
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
        {:error, "Failed to cancel order: #{inspect(reason)}"}
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

  defp cancel_order(api_key, api_secret, passphrase, base_url, params) do
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

        try:
            if params.get("cancel_all", False):
                product_id = params.get("product_id")
                result = rest_client.cancel_all_orders(product_id)
            else:
                order_id = params.get("order_id")
                if not order_id:
                    {"error": "order_id is required when cancel_all is false"}
                else:
                    result = rest_client.cancel_order(order_id)
            result
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
      result when is_map(result) -> {:ok, [result]}
    end
  end
end
defmodule Lux.Prisms.HyperliquidCancelOrderPrism do
  @moduledoc """
  A prism that cancels a specific order on the Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.HyperliquidCancelOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   order_id: 123456,
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5" # Optional
      ...> })
      {:ok,
       %{
         status: "success",
         cancelled_order: %{
           "coin" => "ETH",
           "order_id" => 123456,
           "result" => %{
              # ... cancellation response from Hyperliquid
           }
         }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Order Cancellation",
    description: "Cancels a specific order on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        order_id: %{
          type: :integer,
          description: "Order ID to cancel"
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for executing cancellation",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["coin", "order_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        cancelled_order: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            order_id: %{type: :integer},
            result: %{type: :object}
          },
          required: ["coin", "order_id", "result"]
        }
      },
      required: ["status", "cancelled_order"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- cancel_order(private_key, address, api_url, input) do
      {:ok, %{status: "success", cancelled_order: result}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp cancel_order(private_key, address, api_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Update exchange instance if vault_address is provided
        if "vault_address" in params:
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                vault_address=params["vault_address"]
            )

        result = exchange.cancel(params["coin"], params["order_id"])
        {
            "coin": params["coin"],
            "order_id": params["order_id"],
            "result": result
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

defmodule Lux.Prisms.HyperliquidCancelOrderPrism do
  @moduledoc """
  A prism that cancels orders on the Hyperliquid exchange.

  Supports:
  - Cancelling a specific order by ID
  - Cancelling all orders for a specific coin
  - Cancelling all open orders

  ## Example

      # Cancel a specific order
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

      # Cancel all orders for a coin
      iex> Lux.Prisms.HyperliquidCancelOrderPrism.run(%{
      ...>   action: :cancel_all_for_coin,
      ...>   coin: "ETH",
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{status: "success", cancelled_orders: [...]}}

      # Cancel all open orders
      iex> Lux.Prisms.HyperliquidCancelOrderPrism.run(%{
      ...>   action: :cancel_all,
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{status: "success", cancelled_orders: [...]}}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Order Cancellation",
    description: "Cancels orders on Hyperliquid exchange (specific, by coin, or all)",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: cancel (specific order), cancel_all_for_coin, cancel_all",
          enum: ["cancel", "cancel_all_for_coin", "cancel_all"],
          default: "cancel"
        },
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        order_id: %{
          type: :integer,
          description: "Order ID to cancel (required when action is 'cancel')"
        },
        address: %{
          type: :string,
          description: "Ethereum address for authentication",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for executing cancellation",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["coin"]
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
        },
        cancelled_orders: %{
          type: :array,
          description: "List of cancelled orders (for batch operations)"
        }
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- resolve_address(input),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- cancel_order(private_key, address, api_url, input) do
      {:ok, %{status: "success", cancelled_orders: result}}
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

  defp resolve_address(%{address: addr}) when is_binary(addr) and byte_size(addr) > 0 do
    {:ok, addr}
  end

  defp resolve_address(_) do
    {:ok, Config.hyperliquid_account_address()}
  end

  defp cancel_order(private_key, address, api_url, params) do
    action = Map.get(params, :action, "cancel")

    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params,
               action: action
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Handle vault address override
        if "vault_address" in params and params["vault_address"]:
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                vault_address=params["vault_address"]
            )

        if action == "cancel_all":
            # Cancel all open orders
            open_orders = info.open_orders(address)
            cancelled = []
            for order in open_orders:
                try:
                    result = exchange.cancel(order["coin"], order["oid"])
                    cancelled.append({
                        "coin": order["coin"],
                        "order_id": order["oid"],
                        "result": result
                    })
                except Exception as e:
                    cancelled.append({
                        "coin": order["coin"],
                        "order_id": order["oid"],
                        "error": str(e)
                    })
            cancelled

        elif action == "cancel_all_for_coin":
            # Cancel all orders for a specific coin
            coin = params.get("coin")
            open_orders = info.open_orders(address)
            cancelled = []
            for order in open_orders:
                if order["coin"] == coin:
                    try:
                        result = exchange.cancel(order["coin"], order["oid"])
                        cancelled.append({
                            "coin": order["coin"],
                            "order_id": order["oid"],
                            "result": result
                        })
                    except Exception as e:
                        cancelled.append({
                            "coin": order["coin"],
                            "order_id": order["oid"],
                            "error": str(e)
                        })
            cancelled

        else:
            # Cancel a specific order
            coin = params["coin"]
            order_id = params["order_id"]
            result = exchange.cancel(coin, order_id)
            {
                "coin": coin,
                "order_id": order_id,
                "result": result
            }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      result when is_list(result) -> {:ok, result}
    end
  end
end

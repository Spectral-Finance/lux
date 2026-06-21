defmodule Lux.Prisms.Hyperliquid.ModifyOrderPrism do
  @moduledoc """
  A prism that modifies an existing order on the Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.Hyperliquid.ModifyOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   order_id: 123456,
      ...>   sz: 0.1,
      ...>   limit_px: 2850.0,
      ...>   is_buy: true,
      ...>   order_type: %{limit: %{tif: "Gtc"}},
      ...>   reduce_only: false,
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         status: "success",
         modified_order: %{
           "coin" => "ETH",
           "order_id" => 123456,
           "result" => %{
             # ... modification response from Hyperliquid
           }
         }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Order Modification",
    description: "Modifies an existing order on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        order_id: %{
          type: :integer,
          description: "Order ID to modify"
        },
        is_buy: %{
          type: :boolean,
          description: "True for buy orders, false for sell orders"
        },
        sz: %{
          type: :number,
          description: "New order size in base currency"
        },
        limit_px: %{
          type: :number,
          description: "New limit price for the order"
        },
        order_type: %{
          type: :object,
          description: "Order type configuration",
          properties: %{
            limit: %{
              type: :object,
              properties: %{
                tif: %{
                  type: :string,
                  description:
                    "Time in force: Alo (Allow Limit Only), Ioc (Immediate or Cancel), Gtc (Good Till Cancel)",
                  enum: ["Alo", "Ioc", "Gtc"]
                }
              },
              required: ["tif"]
            }
          },
          required: ["limit"]
        },
        reduce_only: %{
          type: :boolean,
          description: "Whether the order should only reduce position",
          default: false
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for executing orders",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["coin", "order_id", "is_buy", "sz", "limit_px", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        modified_order: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            order_id: %{type: :integer},
            result: %{type: :object}
          },
          required: ["coin", "order_id", "result"]
        }
      },
      required: ["status", "modified_order"]
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
         {:ok, result} <- modify_order(private_key, address, api_url, input) do
      {:ok, %{status: "success", modified_order: result}}
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

  defp modify_order(private_key, address, api_url, params) do
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

        modify_result = exchange.modify_order(
            oid=params["order_id"],
            name=params["coin"],
            is_buy=params["is_buy"],
            sz=params["sz"],
            limit_px=params["limit_px"],
            order_type=params["order_type"],
            reduce_only=params.get("reduce_only", False)
        )

        {
            "coin": params["coin"],
            "order_id": params["order_id"],
            "result": modify_result
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

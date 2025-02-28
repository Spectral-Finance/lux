defmodule Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism do
  @moduledoc """
  A prism that fetches open orders from the Hyperliquid exchange.

  ## Example

      # Get open orders for a specific address
      iex> Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         "status" => "success",
         "open_orders" => [
           %{
             "coin" => "ETH",
             "oid" => 123456,
             "sz" => "0.1",
             "limit_px" => "2800.0",
             "order_type" => %{
               "limit" => %{
                 "tif" => "Gtc"
               }
             },
             "side" => "B",
             "timestamp" => 1678901234567
           }
         ]
       }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid Open Orders",
    description: "Fetches open orders from Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description:
            "Ethereum address to fetch open orders for (can be user's address or vault address)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        open_orders: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              coin: %{type: :string},
              oid: %{type: :integer},
              sz: %{type: :string},
              limit_px: %{type: :string},
              order_type: %{
                type: :object,
                properties: %{
                  limit: %{
                    type: :object,
                    properties: %{
                      tif: %{
                        type: :string,
                        enum: ["Gtc", "Ioc", "Alo"]
                      }
                    }
                  }
                }
              },
              side: %{
                type: :string,
                enum: ["B", "S"],
                description: "B for Buy, S for Sell"
              },
              timestamp: %{type: :integer}
            },
            required: ["coin", "oid", "sz", "limit_px", "order_type", "side"]
          }
        }
      },
      required: ["status", "open_orders"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(%{address: address} = _input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- fetch_open_orders(private_key, address, api_url) do
      {:ok, %{status: "success", open_orders: result}}
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

  defp fetch_open_orders(private_key, target_address, api_url) do
    python_result =
      python variables: %{
               private_key: private_key,
               target_address: target_address,
               api_url: api_url
             } do
        ~PY"""
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, target_address, api_url, skip_ws=True)
        open_orders = info.open_orders(target_address)
        open_orders  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
    end
  end
end

defmodule Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism do
  @moduledoc """
  A prism that fetches user state information from the Hyperliquid exchange.

  ## Example

      # Get state for a specific address
      iex> Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         "status" => "success",
         "user_state" => %{
           "assetPositions" => [
             %{
               "coin" => "ETH",
               "position" => %{
                 "entryPx" => "2800.0",
                 "leverage" => "2.0",
                 "liquidationPx" => "1400.0",
                 "marginUsed" => "1000.0",
                 "positionValue" => "2000.0",
                 "returnOnEquity" => "0.15",
                 "size" => "1.0",
                 # ... other position fields
               }
             }
           ],
           "crossMaintenanceMarginRatio" => "0.0625",
           "crossMarginSummary" => %{
             "accountValue" => "10000.0",
             "totalMarginUsed" => "1000.0",
             "totalNtlPos" => "2000.0",
             "totalRawUsd" => "10000.0"
           }
           # ... other user state fields
         }
       }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid User State",
    description: "Fetches user state information from Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description:
            "Ethereum address to fetch state for (can be user's address or vault address)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        user_state: %{
          type: :object,
          properties: %{
            assetPositions: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  coin: %{type: :string},
                  position: %{
                    type: :object,
                    properties: %{
                      entryPx: %{type: :string},
                      leverage: %{type: :string},
                      liquidationPx: %{type: :string},
                      marginUsed: %{type: :string},
                      positionValue: %{type: :string},
                      returnOnEquity: %{type: :string},
                      size: %{type: :string}
                    }
                  }
                }
              }
            },
            crossMaintenanceMarginRatio: %{type: :string},
            crossMarginSummary: %{
              type: :object,
              properties: %{
                accountValue: %{type: :string},
                totalMarginUsed: %{type: :string},
                totalNtlPos: %{type: :string},
                totalRawUsd: %{type: :string}
              }
            }
          }
        }
      },
      required: ["status", "user_state"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(%{address: address} = _input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- fetch_user_state(private_key, address, api_url) do
      {:ok, %{status: "success", user_state: result}}
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

  defp fetch_user_state(private_key, target_address, api_url) do
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
        user_state = info.user_state(target_address)
        user_state  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

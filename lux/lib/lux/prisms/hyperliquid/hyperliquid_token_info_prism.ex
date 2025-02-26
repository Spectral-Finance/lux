defmodule Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism do
  @moduledoc """
  A prism that fetches token price data from the Hyperliquid API.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism.run(%{})
      {:ok, %{
        prices: %{
          "BTC" => %{
            "funding" => "0.0000125",
            "markPx" => "104050.0",
            # ...other fields
          },
          # ...other tokens
        }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Token Info",
    description: "Fetches token prices from Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{},
      additionalProperties: false
    },
    output_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :object,
          description: "Map of token symbols to price data",
          additionalProperties: %{
            type: :object,
            properties: %{
              funding: %{type: :string},
              openInterest: %{type: :string},
              prevDayPx: %{type: :string},
              dayNtlVlm: %{type: :string},
              premium: %{type: :string},
              oraclePx: %{type: :string},
              markPx: %{type: :string},
              midPx: %{type: :string},
              impactPxs: %{
                type: :array,
                items: %{type: :string}
              },
              dayBaseVlm: %{type: :string},
              szDecimals: %{type: :integer}
            }
          }
        }
      },
      required: ["prices"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(_input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- fetch_token_prices(private_key, address, api_url) do
      {:ok, %{prices: result}}
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

  defp fetch_token_prices(private_key, address, api_url) do
    python_result =
      python variables: %{private_key: private_key, address: address, api_url: api_url} do
        ~PY"""
        from collections import defaultdict
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        def get_token_to_price_mapping(info_obj):
            token_to_price = defaultdict(float)

            token_metadata = info_obj.meta_and_asset_ctxs()
            token_names, token_price = token_metadata[0], token_metadata[1]

            for idx, token_name in enumerate(token_names["universe"]):
                token_to_price[token_name["name"]] = token_price[idx]
                token_to_price[token_name["name"]]["szDecimals"] = token_name["szDecimals"]

            return token_to_price

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)
        price_mapping = get_token_to_price_mapping(info)
        price_mapping  # Return the result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

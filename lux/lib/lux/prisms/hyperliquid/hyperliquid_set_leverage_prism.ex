defmodule Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism do
  @moduledoc """
  A prism for setting leverage on a Hyperliquid perpetual position.

  Supports both cross-margin and isolated-margin leverage configuration.
  Leverage ranges from 1x to the maximum allowed by the exchange for the given asset.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism.run(%{
      ...>   coin: "ETH",
      ...>   leverage: 5,
      ...>   is_cross: true
      ...> })
      {:ok, %{
        coin: "ETH",
        leverage: 5,
        is_cross: true,
        status: "success"
      }}

      iex> Lux.Prisms.Hyperliquid.HyperliquidSetLeveragePrism.run(%{
      ...>   coin: "BTC",
      ...>   leverage: 10,
      ...>   is_cross: false
      ...> })
      {:ok, %{
        coin: "BTC",
        leverage: 10,
        is_cross: false,
        status: "success"
      }}

  The prism reads authentication from config:
  - :hyperliquid_private_key — Ethereum private key for signing
  - :hyperliquid_address — (Optional) account address
  - :hyperliquid_api_url — Exchange API base URL
  """

  use Lux.Prism,
    name: "Hyperliquid Set Leverage",
    description: "Sets leverage for a perpetual position on Hyperliquid (cross or isolated margin)",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Asset symbol to set leverage for (e.g., 'ETH', 'BTC')"
        },
        leverage: %{
          type: :integer,
          description: "Desired leverage multiplier (1–50 depending on asset)",
          minimum: 1,
          maximum: 100
        },
        is_cross: %{
          type: :boolean,
          description: "True for cross-margin, false for isolated-margin",
          default: true
        }
      },
      required: ["coin", "leverage"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, description: "Asset symbol"},
        leverage: %{type: :integer, description: "New leverage value"},
        is_cross: %{type: :boolean, description: "Margin type used"},
        status: %{type: :string, description: "Operation result status"}
      },
      required: ["coin", "leverage", "is_cross", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{coin: coin, leverage: leverage} = input, _ctx) do
    is_cross = Map.get(input, :is_cross, true)
    Logger.info("Setting #{if is_cross, do: "cross", else: "isolated"} leverage #{leverage}x for #{coin}")

    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- set_leverage(private_key, address, api_url, coin, leverage, is_cross) do
      Logger.info("Set leverage #{leverage}x for #{coin}: #{inspect(result)}")
      {:ok, %{coin: coin, leverage: leverage, is_cross: is_cross, status: "success"}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid private key not configured"}
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Package import failed: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp set_leverage(private_key, address, api_url, coin, leverage, is_cross) do
    result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               coin: coin,
               leverage: leverage,
               is_cross: is_cross
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup

        try:
            address, info, exchange = setup(private_key, address, api_url, skip_ws=True)
            result = exchange.update_leverage(leverage, coin, is_cross=is_cross)
            result
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end
end

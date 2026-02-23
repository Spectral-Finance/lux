defmodule Lux.Prisms.Hyperliquid.HyperliquidUpdateMarginPrism do
  @moduledoc """
  A prism for adding or removing margin from an isolated Hyperliquid position.

  Margin management lets you adjust the collateral backing a specific isolated-margin
  position, which changes the effective leverage and liquidation price.

  Positive amounts add margin (reduces leverage/liquidation risk).
  Negative amounts remove margin (increases leverage/liquidation risk).

  ## Example

      # Add $500 USDC margin to ETH isolated position
      iex> HyperliquidUpdateMarginPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount_usd: 500.0
      ...> })
      {:ok, %{
        coin: "ETH",
        amount_usd: 500.0,
        direction: "added",
        status: "success"
      }}

      # Remove $200 USDC from ETH isolated position
      iex> HyperliquidUpdateMarginPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount_usd: -200.0
      ...> })
      {:ok, %{
        coin: "ETH",
        amount_usd: -200.0,
        direction: "removed",
        status: "success"
      }}

  Authentication from config:
  - :hyperliquid_private_key — signing key
  - :hyperliquid_api_url — exchange endpoint
  """

  use Lux.Prism,
    name: "Hyperliquid Update Margin",
    description: "Adds or removes margin from an isolated Hyperliquid position",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Asset symbol (e.g., 'ETH', 'BTC')"
        },
        amount_usd: %{
          type: :number,
          description: "USD amount to add (positive) or remove (negative)"
        }
      },
      required: ["coin", "amount_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string},
        amount_usd: %{type: :number},
        direction: %{type: :string, description: "'added' or 'removed'"},
        status: %{type: :string}
      },
      required: ["coin", "amount_usd", "direction", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{coin: coin, amount_usd: amount_usd}, _ctx) do
    direction = if amount_usd >= 0, do: "added", else: "removed"
    Logger.info("Updating margin for #{coin}: #{direction} $#{abs(amount_usd)}")

    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, _result} <- update_margin(private_key, address, api_url, coin, amount_usd) do
      {:ok, %{coin: coin, amount_usd: amount_usd, direction: direction, status: "success"}}
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

  defp update_margin(private_key, address, api_url, coin, amount_usd) do
    result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               coin: coin,
               amount_usd: amount_usd
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup
        import math

        try:
            address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

            # amount must be in raw USD units (integer)
            raw_amount = int(math.floor(abs(amount_usd))) * (1 if amount_usd >= 0 else -1)
            result = exchange.update_isolated_margin(raw_amount, coin)
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

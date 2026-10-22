defmodule Lux.Prisms.Hyperliquid.HyperliquidUpdateLeveragePrism do
  @moduledoc """
  A prism that configures leverage for a perpetual market on Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidUpdateLeveragePrism.run(%{
      ...>   coin: "BTC",
      ...>   leverage: 10,
      ...>   is_cross: true
      ...> })
      {:ok, %{status: "success", coin: "BTC", leverage: 10, result: %{...}}}
  """

  use Lux.Prism,
    name: "Hyperliquid Update Leverage",
    description: "Updates leverage and margin mode for perpetual positions on Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading coin symbol (e.g. BTC, ETH)"
        },
        leverage: %{
          type: :integer,
          description: "Target leverage (1 to 100)",
          minimum: 1,
          maximum: 100
        },
        is_cross: %{
          type: :boolean,
          description: "Whether to use cross margin (true) or isolated margin (false)",
          default: true
        }
      },
      required: ["coin", "leverage"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        coin: %{type: :string},
        leverage: %{type: :integer},
        result: %{type: :object}
      },
      required: ["status", "coin", "leverage"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python
  require Logger

  def handler(%{coin: coin, leverage: leverage} = input, _ctx) do
    is_cross = Map.get(input, :is_cross, true)

    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <-
           execute_update_leverage(private_key, address, api_url, coin, leverage, is_cross) do
      {:ok, %{status: "success", coin: coin, leverage: leverage, result: result}}
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

  defp execute_update_leverage(private_key, address, api_url, coin, leverage, is_cross) do
    python_result =
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

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)
        res = exchange.update_leverage(leverage, coin, is_cross=is_cross)
        res
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      other -> {:ok, %{"response" => other}}
    end
  end
end

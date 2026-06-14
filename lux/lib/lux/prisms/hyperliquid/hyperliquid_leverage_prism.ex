defmodule Lux.Prisms.Hyperliquid.HyperliquidLeveragePrism do
  @moduledoc """
  A prism that sets leverage for a trading pair on Hyperliquid.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidLeveragePrism.run(%{
      ...>   coin: "ETH",
      ...>   leverage: 5,
      ...>   is_cross: true
      ...> })
      {:ok, %{status: "success", leverage_result: %{}, coin: "ETH", leverage: 5, margin_mode: "cross"}}

      iex> Lux.Prisms.Hyperliquid.HyperliquidLeveragePrism.run(%{
      ...>   coin: "BTC",
      ...>   leverage: 10,
      ...>   is_cross: false
      ...> })
      {:ok, %{status: "success", leverage_result: %{}, coin: "BTC", leverage: 10, margin_mode: "isolated"}}
  """

  use Lux.Prism,
    name: "Hyperliquid Leverage Control",
    description: "Sets cross or isolated leverage for a trading pair on Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol e.g. ETH, BTC"
        },
        leverage: %{
          type: :integer,
          description: "Leverage multiplier 1-100",
          minimum: 1,
          maximum: 100
        },
        is_cross: %{
          type: :boolean,
          description: "true = cross margin, false = isolated margin",
          default: true
        }
      },
      required: ["coin", "leverage"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        leverage_result: %{type: :object},
        coin: %{type: :string},
        leverage: %{type: :integer},
        margin_mode: %{type: :string}
      },
      required: ["status", "leverage_result"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    coin     = input[:coin]     || input["coin"]
    leverage = input[:leverage] || input["leverage"]
    is_cross = Map.get(input, :is_cross, Map.get(input, "is_cross", true))

    with {:ok, private_key} <- get_private_key(),
         {:ok, address}     <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url}     <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- set_leverage(private_key, address, api_url, coin, leverage, is_cross) do
      {:ok, %{
        status: "success",
        leverage_result: result,
        coin: coin,
        leverage: leverage,
        margin_mode: if(is_cross, do: "cross", else: "isolated")
      }}
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
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Official SDK: update_leverage(leverage: int, name: str, is_cross: bool = True)
        result = exchange.update_leverage(
          int(leverage),
          coin,
          bool(is_cross) if is_cross is not None else True
        )

        if result is None:
          {"error": "No response from API"}
        elif isinstance(result, dict) and result.get("status") == "err":
          {"error": result.get("response", "Unknown error")}
        else:
          result if isinstance(result, dict) else {"raw": str(result)}
        """
      end

    case result do
      %{"error" => e} -> {:error, e}
      r when is_map(r) -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end
end

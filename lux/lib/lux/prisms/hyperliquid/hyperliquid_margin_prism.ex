defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginPrism do
  @moduledoc """
  A prism that manages isolated margin on Hyperliquid positions.

  ## Example

      # Add margin
      iex> Lux.Prisms.Hyperliquid.HyperliquidMarginPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount: 100.0
      ...> })
      {:ok, %{status: "success", margin_result: %{}, coin: "ETH", amount: 100.0}}

      # Remove margin (negative amount)
      iex> Lux.Prisms.Hyperliquid.HyperliquidMarginPrism.run(%{
      ...>   coin: "ETH",
      ...>   amount: -50.0
      ...> })
      {:ok, %{status: "success", margin_result: %{}, coin: "ETH", amount: -50.0}}
  """

  use Lux.Prism,
    name: "Hyperliquid Margin Management",
    description: "Adds or removes isolated margin from Hyperliquid positions",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol e.g. ETH, BTC"
        },
        amount: %{
          type: :number,
          description: "USD amount. Positive = add margin, Negative = remove margin"
        }
      },
      required: ["coin", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        margin_result: %{type: :object},
        coin: %{type: :string},
        amount: %{type: :number}
      },
      required: ["status", "margin_result"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    coin   = input[:coin]   || input["coin"]
    amount = input[:amount] || input["amount"]

    with {:ok, private_key} <- get_private_key(),
         {:ok, address}     <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url}     <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- update_margin(private_key, address, api_url, coin, amount) do
      {:ok, %{
        status: "success",
        margin_result: result,
        coin: coin,
        amount: amount
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

  defp update_margin(private_key, address, api_url, coin, amount) do
    result =
      python variables: %{
        private_key: private_key,
        address: address,
        api_url: api_url,
        coin: coin,
        amount: amount
      } do
        ~PY"""
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Official SDK: update_isolated_margin(amount: float, name: str)
        # isBuy is hardcoded True internally by SDK
        result = exchange.update_isolated_margin(
          float(amount),
          coin
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

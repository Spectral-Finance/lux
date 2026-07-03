defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginManagementPrism do
  @moduledoc """
  A prism that manages leverage and margin for positions on the Hyperliquid exchange.

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Margin Management",
    description: "Manages leverage and adds/removes margin on Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, description: "Trading pair symbol (e.g., 'ETH', 'BTC')"},
        leverage: %{type: :number, description: "Leverage value to set (e.g. 5, 10, 20)"},
        margin_to_add: %{type: :number, description: "Optional margin amount to add (negative to remove, 0 if none)"}
      },
      required: ["coin", "leverage"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object, description: "Raw response from Hyperliquid API"}
      },
      required: ["status", "result"]
    }

  import Lux.Python
  require Lux.Python
  alias Lux.Config

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- execute_margin_management(private_key, address, api_url, input) do
      {:ok, %{status: "success", result: result}}
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

  defp execute_margin_management(private_key, address, api_url, params) do
    coin = params.coin
    leverage = params.leverage
    margin_to_add = Map.get(params, :margin_to_add, 0)

    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               coin: coin,
               leverage: leverage,
               margin_to_add: margin_to_add
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # 1. Update leverage
        leverage_result = exchange.update_leverage(int(leverage), coin)

        # Trata erros da API no ajuste de alavancagem
        if leverage_result.get("status") == "err":
            raise Exception(leverage_result.get("response", "Failed to update leverage"))

        # 2. Optionally add/remove margin (aceita positivo e negativo)
        margin_result = {"status": "skipped"}
        if float(margin_to_add) != 0:
            margin_result = exchange.update_margin(float(margin_to_add), coin)
            # Trata erros da API no ajuste de margem
            if margin_result.get("status") == "err":
                raise Exception(margin_result.get("response", "Failed to update margin"))

        {"status": "completed", "leverage": leverage_result, "margin": margin_result}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
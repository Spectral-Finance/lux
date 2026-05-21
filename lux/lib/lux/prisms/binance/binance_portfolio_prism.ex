defmodule Lux.Prisms.Binance.BinancePortfolioPrism do
  @moduledoc """
  A prism that fetches portfolio balances and active positions on Binance.
  """

  use Lux.Prism,
    name: "Binance Portfolio",
    description: "Fetches balances and positions on Binance Spot and Futures",
    input_schema: %{
      type: :object,
      properties: %{
        market_type: %{
          type: :string,
          description: "Market to query: SPOT or FUTURES",
          enum: ["SPOT", "FUTURES"],
          default: "SPOT"
        },
        testnet: %{
          type: :boolean,
          description: "Use Binance Testnet",
          default: false
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        balances: %{type: :array, description: "List of balances"},
        positions: %{type: :array, description: "List of active futures positions (only for FUTURES market)"}
      },
      required: ["status", "balances"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.client"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance_utils.setup"),
         {:ok, result} <- fetch_portfolio(api_key, api_secret, input) do
      {:ok, Map.put(result, :status, "success")}
    else
      {:error, :missing_api_key} -> {:error, "Binance API Key is not configured"}
      {:error, :missing_api_secret} -> {:error, "Binance API Secret is not configured"}
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import required packages: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_api_key, do: {:ok, Config.binance_api_key()}
  rescue RuntimeError -> {:error, :missing_api_key}

  defp get_api_secret, do: {:ok, Config.binance_api_secret()}
  rescue RuntimeError -> {:error, :missing_api_secret}

  defp fetch_portfolio(api_key, api_secret, params) do
    python_result =
      python variables: %{api_key: api_key, api_secret: api_secret, params: params} do
        ~PY"""
        from binance_utils.setup import setup
        import traceback

        try:
            market_type = params.get("market_type", "SPOT")
            testnet = params.get("testnet", False)
            client = setup(api_key, api_secret, testnet=testnet)

            if market_type == "SPOT":
                account_info = client.get_account()
                # Filter out zero balances
                balances = [b for b in account_info.get("balances", []) if float(b.get("free", 0)) > 0 or float(b.get("locked", 0)) > 0]
                result = {"balances": balances}
                
            elif market_type == "FUTURES":
                account_info = client.futures_account()
                balances = account_info.get("assets", [])
                
                # Active positions
                all_positions = client.futures_position_information()
                active_positions = [p for p in all_positions if float(p.get("positionAmt", 0)) != 0]
                
                result = {"balances": balances, "positions": active_positions}
            else:
                result = {"error": f"Unsupported market type: {market_type}"}
            
            result
        except Exception as e:
            {"error": str(e), "traceback": traceback.format_exc()}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, Lux.Utils.atomize_keys(result)}
    end
  end
end

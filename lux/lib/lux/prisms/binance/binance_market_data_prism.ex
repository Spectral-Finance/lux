defmodule Lux.Prisms.Binance.BinanceMarketDataPrism do
  @moduledoc """
  A prism that fetches market data (klines/candlesticks, order book) on Binance.
  """

  use Lux.Prism,
    name: "Binance Market Data",
    description: "Fetches market data on Binance Spot and Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETHUSDT')"
        },
        data_type: %{
          type: :string,
          description: "Data to fetch: KLINES or ORDER_BOOK",
          enum: ["KLINES", "ORDER_BOOK"],
          default: "KLINES"
        },
        interval: %{
          type: :string,
          description: "Klines interval (e.g. 1m, 1h, 1d). Required if data_type is KLINES."
        },
        limit: %{
          type: :number,
          description: "Number of data points to return"
        },
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
      },
      required: ["symbol", "data_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object, description: "Market data payload"}
      },
      required: ["status", "data"]
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.client"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance_utils.setup"),
         {:ok, result} <- fetch_market_data(input) do
      {:ok, %{status: "success", data: result}}
    else
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import required packages: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_market_data(params) do
    python_result =
      python variables: %{params: params} do
        ~PY"""
        from binance_utils.setup import setup
        import traceback

        try:
            market_type = params.get("market_type", "SPOT")
            testnet = params.get("testnet", False)
            symbol = params.get("symbol")
            data_type = params.get("data_type", "KLINES")
            limit = params.get("limit", 100)
            
            # Anonymous client (no API keys required for public data)
            client = setup("", "", testnet=testnet)

            if data_type == "KLINES":
                interval = params.get("interval", "1h")
                if market_type == "SPOT":
                    data = client.get_klines(symbol=symbol, interval=interval, limit=limit)
                elif market_type == "FUTURES":
                    data = client.futures_klines(symbol=symbol, interval=interval, limit=limit)
                else:
                    data = {"error": f"Unsupported market type: {market_type}"}
                
                # Format klines
                if isinstance(data, list) and not isinstance(data, dict):
                    formatted = []
                    for k in data:
                        formatted.append({
                            "open_time": k[0],
                            "open": k[1],
                            "high": k[2],
                            "low": k[3],
                            "close": k[4],
                            "volume": k[5]
                        })
                    result = {"klines": formatted}
                else:
                    result = data
                    
            elif data_type == "ORDER_BOOK":
                if market_type == "SPOT":
                    data = client.get_order_book(symbol=symbol, limit=limit)
                elif market_type == "FUTURES":
                    data = client.futures_order_book(symbol=symbol, limit=limit)
                else:
                    data = {"error": f"Unsupported market type: {market_type}"}
                
                result = {"order_book": data}
            else:
                result = {"error": f"Unsupported data type: {data_type}"}
            
            result
        except Exception as e:
            {"error": str(e), "traceback": traceback.format_exc()}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

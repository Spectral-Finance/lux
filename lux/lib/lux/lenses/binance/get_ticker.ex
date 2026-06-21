defmodule Lux.Lenses.Binance.GetTicker do
  @moduledoc """
  A lens for retrieving ticker information from Binance.
  Supports both Spot and Futures networks.
  """

  use Lux.Lens,
    name: "Binance Ticker Data",
    description: "Fetches current ticker price for a specific symbol on Binance Spot or Futures",
    url: "https://api.binance.com/api/v3/ticker/price",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTCUSDT)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        },
        network: %{
          type: :string,
          enum: ["spot", "futures"],
          description: "The Binance network to use (spot or futures)",
          default: "spot"
        }
      },
      required: ["symbol"]
    }

  @doc """
  Adjusts the URL based on the network parameter.
  """
  @impl true
  def before_focus(params, lens) do
    network = Map.get(params, :network, "spot")
    
    url = case network do
      "futures" -> "https://fapi.binance.com/fapi/v1/ticker/price"
      _ -> "https://api.binance.com/api/v3/ticker/price"
    end

    params_for_req = %{symbol: String.upcase(params.symbol)}
    
    # Remove network from params sent to API
    {:ok, %{lens | url: url, params: params_for_req}}
  end

  @doc """
  Transforms the Binance API response into a simpler format.
  """
  @impl true
  def after_focus(%{"symbol" => symbol, "price" => price}) do
    {:ok, %{
      symbol: symbol,
      price: price
    }}
  end

  def after_focus(%{"msg" => msg, "code" => code}) do
    {:error, %{message: msg, code: code}}
  end
  
  def after_focus(error), do: {:error, error}
end

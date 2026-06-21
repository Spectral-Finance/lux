defmodule Lux.Lenses.Binance.GetAccountState do
  @moduledoc """
  A lens for retrieving account information and balances from Binance.
  Supports both Spot and Futures networks.
  """

  alias Lux.Integrations.Binance

  use Lux.Lens,
    name: "Binance Account State",
    description: "Fetches account state and balances on Binance Spot or Futures",
    url: "https://api.binance.com/api/v3/account",
    method: :get,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{
        network: %{
          type: :string,
          enum: ["spot", "futures"],
          description: "The Binance network to use (spot or futures)",
          default: "spot"
        }
      }
    }

  @impl true
  def before_focus(params, lens) do
    network = Map.get(params, :network, "spot")
    
    url = case network do
      "futures" -> "https://fapi.binance.com/fapi/v2/account"
      _ -> "https://api.binance.com/api/v3/account"
    end

    {:ok, %{lens | url: url, params: %{}}}
  end

  @impl true
  def after_focus(%{"balances" => balances}) do
    # Spot response
    non_zero = Enum.filter(balances, fn b -> 
      String.to_float(b["free"]) > 0.0 or String.to_float(b["locked"]) > 0.0
    end)
    
    {:ok, %{
      balances: Enum.map(non_zero, fn b ->
        %{
          asset: b["asset"],
          free: b["free"],
          locked: b["locked"]
        }
      end)
    }}
  end

  def after_focus(%{"assets" => assets}) do
    # Futures response (fapi/v2/account returns assets array)
    non_zero = Enum.filter(assets, fn a -> 
      String.to_float(a["walletBalance"]) > 0.0
    end)
    
    {:ok, %{
      balances: Enum.map(non_zero, fn a ->
        %{
          asset: a["asset"],
          free: a["availableBalance"],
          locked: Float.to_string(String.to_float(a["walletBalance"]) - String.to_float(a["availableBalance"]))
        }
      end)
    }}
  end

  def after_focus(%{"msg" => msg, "code" => code}) do
    {:error, %{message: msg, code: code}}
  end
  
  def after_focus(error), do: {:error, error}
end

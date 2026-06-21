defmodule Lux.Lenses.Coinbase.GetAccountState do
  @moduledoc """
  A lens for retrieving account balances from Coinbase Advanced Trade.
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Account State",
    description: "Fetches account state and balances on Coinbase",
    url: "https://api.coinbase.com/api/v3/brokerage/accounts",
    method: :get,
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def after_focus(%{"accounts" => accounts}) do
    non_zero = Enum.filter(accounts, fn a -> 
      String.to_float(a["available_balance"]["value"]) > 0.0 or String.to_float(a["hold"]["value"]) > 0.0
    end)
    
    {:ok, %{
      balances: Enum.map(non_zero, fn a ->
        %{
          asset: a["currency"],
          free: a["available_balance"]["value"],
          locked: a["hold"]["value"]
        }
      end)
    }}
  end

  def after_focus(%{"error_response" => %{"message" => message}}) do
    {:error, message}
  end
  
  def after_focus(error), do: {:error, error}
end

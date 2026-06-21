defmodule Lux.Lenses.Coinbase.GetAccountState do
  @moduledoc """
  A lens for retrieving account balances from Coinbase Advanced Trade.
  """

  use Lux.Lens,
    name: "Coinbase Account State",
    description: "Fetches account balances from Coinbase",
    params: %{
      limit: %{
        type: :integer,
        description: "Number of accounts to return",
        default: 100
      }
    }

  alias Lux.Integrations.Coinbase.Client

  @impl true
  def focus(params, _assigns) do
    path = "/api/v3/brokerage/accounts"

    query_params = %{
      "limit" => Map.get(params, :limit, 100)
    }

    case Client.request(:get, path, signed: true, params: query_params) do
      {:ok, response} ->
        {:ok, normalize_balances(response)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_balances(%{"accounts" => accounts} = response) do
    balances =
      accounts
      |> Enum.map(fn a ->
        %{
          "asset" => a["currency"],
          "free" => a["available_balance"]["value"],
          "locked" => a["hold"]["value"],
          "uuid" => a["uuid"]
        }
      end)

    Map.put(response, "normalized_balances", balances)
  end

  defp normalize_balances(response), do: response
end

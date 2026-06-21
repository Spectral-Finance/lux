defmodule Lux.Lenses.Binance.GetAccountState do
  @moduledoc """
  A lens for retrieving account information and balances from Binance.
  Supports both Spot and Futures networks.
  """

  use Lux.Lens,
    name: "Binance Account State",
    description: "Fetches account state and balances on Binance Spot or Futures",
    params: %{
      network: %{
        type: :string,
        description: "The network to use ('spot' or 'futures')",
        default: "spot"
      }
    }

  alias Lux.Integrations.Binance.Client

  @impl true
  def focus(params, _assigns) do
    network =
      case Map.get(params, :network, "spot") do
        "spot" -> :spot
        "futures" -> :futures
        "spot" -> :spot
        other -> String.to_existing_atom(other)
      end

    path =
      case network do
        :spot -> "/api/v3/account"
        :futures -> "/fapi/v2/account"
      end

    case Client.request(:get, path, %{network: network, signed: true}) do
      {:ok, response} ->
        {:ok, normalize_balances(network, response)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_balances(:spot, response) do
    balances =
      response
      |> Map.get("balances", [])
      |> Enum.map(fn b ->
        %{
          "asset" => b["asset"],
          "free" => b["free"],
          "locked" => b["locked"]
        }
      end)

    Map.put(response, "normalized_balances", balances)
  end

  defp normalize_balances(:futures, response) do
    balances =
      response
      |> Map.get("assets", [])
      |> Enum.map(fn b ->
        %{
          "asset" => b["asset"],
          "free" => b["availableBalance"],
          "wallet_balance" => b["walletBalance"]
        }
      end)

    Map.put(response, "normalized_balances", balances)
  end
end

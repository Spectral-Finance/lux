defmodule Lux.Lenses.Blur.Sales.GetCollectionSales do
  @moduledoc """
  A lens for retrieving recent sales for an NFT collection from the Blur marketplace.

  This lens provides:
  - Recent sale prices and tokens
  - Buyer and seller addresses
  - NFT token IDs
  - Sale timestamps
  - Marketplace source (Blur vs OpenSea via aggregator)

  ## Examples

      iex> GetCollectionSales.focus(%{
      ...>   contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
      ...> })
      {:ok, %{
        sales: [
          %{
            token_id: "1234",
            price: 10.2,
            price_currency: "ETH",
            seller: "0x...",
            buyer: "0x...",
            timestamp: "2024-01-15T12:00:00Z",
            marketplace: "blur"
          }
        ],
        count: 1
      }}
  """

  alias Lux.Integrations.Blur

  use Lux.Lens,
    name: "Get Blur Collection Sales",
    description: "Retrieves recent sales history for an NFT collection from Blur",
    url: "https://core-api.prod.blur.io/v1/collections/:contract_address/sales",
    method: :get,
    headers: Blur.headers(),
    auth: Blur.auth(),
    schema: %{
      type: :object,
      properties: %{
        contract_address: %{
          type: :string,
          description: "The contract address of the NFT collection",
          pattern: "^0x[0-9a-fA-F]{40}$"
        }
      },
      required: ["contract_address"]
    }

  @doc """
  Transforms the Blur sales API response.
  """
  @impl true
  def after_focus(%{"sales" => sales}) do
    formatted = Enum.map(sales, fn sale ->
      %{
        token_id: to_string(sale["tokenId"] || sale["token_id"]),
        price: parse_price(sale["price"]),
        price_currency: sale["currency"] || "ETH",
        seller: sale["seller"],
        buyer: sale["buyer"],
        timestamp: sale["createdAt"] || sale["timestamp"],
        marketplace: "blur",
        transaction_hash: sale["txHash"] || sale["transaction_hash"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)

    {:ok, %{sales: formatted, count: length(formatted)}}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{message: message}}
  end

  def after_focus(%{"error" => error}) do
    {:error, %{error: error}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_price(nil), do: nil
  defp parse_price(%{"amount" => amount}) when is_binary(amount) do
    case Float.parse(amount) do
      {f, ""} -> f
      _ -> nil
    end
  end
  defp parse_price(%{"amount" => amount}) when is_number(amount), do: amount
  defp parse_price(n) when is_number(n), do: n
  defp parse_price(s) when is_binary(s) do
    case Float.parse(s) do
      {f, ""} -> f
      _ -> nil
    end
  end
  defp parse_price(_), do: nil
end

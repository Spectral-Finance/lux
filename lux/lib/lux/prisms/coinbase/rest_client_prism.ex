defmodule Lux.Prisms.Coinbase.RestClientPrism do
  @moduledoc """
  Prism for dispatching REST requests to Coinbase Advanced Trade.
  """
  use Lux.Prism,
    name: "Coinbase REST Client Prism",
    description: "Executes authenticated and public REST API calls to Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        endpoint: %{
          type: :string,
          description: "Target API endpoint or operation name (e.g. products, accounts, candles)"
        },
        params: %{
          type: :object,
          description: "Key-value query parameters or request payload"
        }
      },
      required: ["endpoint"]
    }

  require Logger
  import Lux.Python

  @impl true
  def handler(input, _ctx) do
    endpoint = Map.get(input, "endpoint") || Map.get(input, :endpoint)
    params = Map.get(input, "params") || Map.get(input, :params) || %{}

    python_result =
      python variables: %{
               endpoint: endpoint,
               params: params
             } do
        ~PY"""
        from lux.coinbase.rest import CoinbaseRestClient
        from lux.coinbase.types import Granularity

        client = CoinbaseRestClient()
        res = {}

        if endpoint in ("products", "get_products"):
            limit = params.get("limit", 250)
            res = {"products": [p.model_dump() for p in client.get_products(limit=limit)]}
        elif endpoint in ("product", "get_product"):
            p_id = params.get("product_id", "")
            res = {"product": client.get_product(p_id).model_dump()}
        elif endpoint in ("candles", "get_candles"):
            p_id = params.get("product_id", "")
            gran = params.get("granularity", "ONE_HOUR")
            candles = client.get_candles(product_id=p_id, granularity=gran)
            res = {"candles": [c.model_dump() for c in candles]}
        elif endpoint in ("best_bid_ask", "get_best_bid_ask"):
            p_ids = params.get("product_ids")
            tickers = client.get_best_bid_ask(product_ids=p_ids)
            res = {"tickers": [t.model_dump() for t in tickers]}
        elif endpoint in ("accounts", "get_accounts"):
            accounts = client.get_accounts()
            res = {"accounts": [a.model_dump() for a in accounts]}
        elif endpoint in ("transaction_summary", "get_transaction_summary"):
            res = client.get_transaction_summary()
        else:
            res = {"error": f"Unknown endpoint action: {endpoint}"}

        res
        """
      end

    case python_result do
      %{"error" => err} -> {:error, err}
      result when is_map(result) -> {:ok, result}
      other -> {:error, "Unexpected prism response: #{inspect(other)}"}
    end
  end
end

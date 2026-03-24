defmodule Lux.Prisms.Coinbase.CoinbaseProductsPrism do
  @moduledoc """
  A prism that fetches available trading products from the Coinbase Exchange.

  ## Example

      # Get all products
      iex> Lux.Prisms.Coinbase.CoinbaseProductsPrism.run(%{})
      {:ok,
       %{
         status: "success",
         products: [
           %{
             "id" => "BTC-USD",
             "base_currency" => "BTC",
             "quote_currency" => "USD",
             "base_min_size" => "0.001",
             "base_max_size" => "1000",
             "status" => "online"
           }
         ]
       }}

      # Get specific product
      iex> Lux.Prisms.Coinbase.CoinbaseProductsPrism.run(%{
      ...>   product_id: "BTC-USD"
      ...> })

  This endpoint does not require authentication.
  """

  use Lux.Prism,
    name: "Coinbase Products",
    description: "Fetches available trading products from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Specific product ID to fetch (optional)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        products: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              base_currency: %{type: :string},
              quote_currency: %{type: :string},
              base_min_size: %{type: :string},
              base_max_size: %{type: :string},
              quote_increment: %{type: :string},
              status: %{type: :string},
              trading_disabled: %{type: :boolean},
              cancel_only: %{type: :boolean},
              limit_only: %{type: :boolean},
              post_only: %{type: :boolean}
            }
          }
        },
        error: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, base_url} <- {:ok, Config.coinbase_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- fetch_products(base_url, input) do
      {:ok, %{status: "success", products: result}}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to fetch products: #{inspect(reason)}"}
    end
  end

  defp fetch_products(base_url, params) do
    python_result =
      python variables: %{
               base_url: base_url,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import CoinbaseRestClient

        rest_client = CoinbaseRestClient("", "", "", base_url)

        product_id = params.get("product_id")

        try:
            if product_id:
                product = rest_client.get_product(product_id)
                [product]
            else:
                rest_client.get_products()
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
    end
  end
end
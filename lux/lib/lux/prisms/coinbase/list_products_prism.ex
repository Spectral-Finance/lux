defmodule Lux.Prisms.Coinbase.ListProductsPrism do
  @moduledoc """
  A prism that lists all available Coinbase trading products.

  ## Example

      iex> Lux.Prisms.Coinbase.ListProductsPrism.run(%{
      ...>   product_type: "SPOT",
      ...>   limit: 10
      ...> })
      {:ok, %{products: [...], total_count: 123}}

  Uses the `coinbase-advanced-py` Python SDK.
  """

  use Lux.Prism,
    name: "Coinbase List Products",
    description: "Lists all available Coinbase trading products with optional filtering",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{
          type: :integer,
          description: "Maximum number of products to return"
        },
        offset: %{
          type: :integer,
          description: "Offset for pagination"
        },
        product_type: %{
          type: :string,
          description: "Filter by product type",
          enum: ["SPOT", "FUTURE"]
        },
        product_ids: %{
          type: :array,
          description: "Filter by specific product IDs",
          items: %{type: :string}
        },
        get_all_products: %{
          type: :boolean,
          description: "Include non-tradable products",
          default: false
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        products: %{type: :array, description: "List of product objects"},
        total_count: %{type: :integer, description: "Total number of products matching filters"}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      from coinbase.rest.products import get_products

      api_key = os.getenv("COINBASE_API_KEY", "")
      api_secret = os.getenv("COINBASE_API_SECRET", "")

      # Public endpoint - no auth needed for listing products
      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret if api_key else None)

      # Bind the method
      get_products.__self__ = client

      # Build params
      params = {}
      if isinstance(input, dict):
          for k in ["limit", "offset", "product_type", "get_all_products"]:
              if k in input and input[k] is not None:
                  params[k] = input[k]
          if "product_ids" in input and input["product_ids"] is not None:
              params["product_ids"] = input["product_ids"]

      response = get_products(**params)
      {
          "products": response.data,
          "total_count": len(response.data) if hasattr(response, 'data') else 0
      }
      """
    end
    |> handle_python_result()
  end

  defp handle_python_result(%{"error" = err} = result) when is_binary(err) do
    {:error, result}
  end

  defp handle_python_result(%{"error" => err}) when is_binary(err) do
    {:error, err}
  end

  defp handle_python_result(%{"products" => products}) do
    {:ok, %{products: products, total_count: length(products)}}
  end

  defp handle_python_result(result) when is_map(result) do
    {:ok, result}
  end

  defp handle_python_result({:error, error}) do
    {:error, error}
  end
end

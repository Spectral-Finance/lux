defmodule Lux.Prisms.TvlPrism do
  @moduledoc """
  A prism that checks Total Value Locked (TVL) of a DeFi protocol using DeFiLlama API.

  ## Examples

      iex> Lux.Prisms.TvlPrism.run(%{protocol: "uniswap"})
      {:ok, %{
        tvl: 3654321098.76,
        protocol: "uniswap"
      }}
  """

  use Lux.Prism,
    name: "TVL Checker",
    description: "Checks Total Value Locked (TVL) of a DeFi protocol",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug from DeFiLlama"
        }
      },
      required: ["protocol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tvl: %{
          type: :number,
          description: "Total Value Locked in USD"
        },
        protocol: %{
          type: :string,
          description: "Protocol slug used for query"
        }
      },
      required: ["tvl", "protocol"]
    }

  import Lux.Python

  require Lux.Python

  def handler(%{protocol: protocol} = input, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("requests"),
         {:ok, result} <- get_tvl(protocol) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import requests: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_tvl(protocol) do
    result =
      python variables: %{protocol: protocol} do
        ~PY"""
        import requests

        def fetch_tvl(protocol):
            url = f"https://api.llama.fi/tvl/{protocol}"
            try:
                response = requests.get(url, timeout=10)
                response.raise_for_status()
                return {
                    "tvl": float(response.text),
                    "protocol": protocol
                }
            except requests.HTTPError as e:
                return {"error": f"HTTP error {e.response.status_code}: {str(e)}"}
            except ValueError as e:
                return {"error": f"Invalid TVL format: {str(e)}"}
            except Exception as e:
                return {"error": f"Request failed: {str(e)}"}

        result = fetch_tvl(protocol)
        result
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end

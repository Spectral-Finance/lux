defmodule Lux.Prisms.Defi.AnalyticsDashboardPrism do
  @moduledoc """
  A Prism that aggregates DeFi analytics data from various lenses to create
  a comprehensive analytics dashboard for a specific protocol.

  This prism uses:
  - DeFiLlama GetProtocols to find protocol TVL and metrics
  - DeFiLlama GetYields to find the best performing pools for the protocol
  - Dune Analytics GetQueryResults (optional) to fetch custom query analytics
  """
  use Lux.Prism,
    name: "DeFi Analytics Dashboard",
    description: "Aggregates DeFi metrics (TVL, Yields, etc.) for a specific protocol",
    input_schema: %{
      type: :object,
      properties: %{
        protocol_slug: %{
          type: :string,
          description: "The slug of the protocol on DeFiLlama (e.g., 'aave', 'uniswap', 'makerdao')"
        },
        dune_execution_id: %{
          type: :string,
          description: "Optional Dune Analytics execution ID for custom query data"
        }
      },
      required: ["protocol_slug"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :object,
          description: "Protocol TVL and metrics"
        },
        pools: %{
          type: :array,
          description: "Top yield pools for the protocol"
        },
        custom_analytics: %{
          type: :object,
          description: "Custom analytics from Dune queries (if requested)"
        }
      },
      required: ["protocol", "pools"]
    }

  @doc """
  Runs the analytics dashboard aggregation.
  """
  def handler(input, _ctx) do
    protocol_slug = Map.get(input, :protocol_slug) || Map.get(input, "protocol_slug")
    dune_execution_id = Map.get(input, :dune_execution_id) || Map.get(input, "dune_execution_id")

    with {:ok, protocols} <- Lux.Lenses.DefiLlama.GetProtocols.focus(),
         protocol when not is_nil(protocol) <- find_protocol(protocols, protocol_slug),
         {:ok, all_pools} <- Lux.Lenses.DefiLlama.GetYields.focus(),
         pools <- filter_protocol_pools(all_pools, protocol["name"]) do
      
      custom_analytics = 
        if dune_execution_id do
          case Lux.Lenses.Dune.GetQueryResults.focus(%{execution_id: dune_execution_id}) do
            {:ok, result} -> result
            _ -> nil
          end
        else
          nil
        end

      result = %{
        protocol: protocol,
        pools: pools,
        custom_analytics: custom_analytics
      }
      
      {:ok, result}
    else
      nil -> {:error, "Protocol not found"}
      {:error, reason} -> {:error, reason}
      error -> {:error, inspect(error)}
    end
  end

  defp find_protocol(protocols, slug) do
    Enum.find(protocols, fn p -> p["slug"] == slug end)
  end

  defp filter_protocol_pools(pools, protocol_name) do
    pools
    |> Enum.filter(fn p -> p["project"] == String.downcase(protocol_name) || p["project"] == protocol_name end)
    |> Enum.sort_by(fn p -> p["tvlUsd"] || 0 end, :desc)
    |> Enum.take(5)
  end
end

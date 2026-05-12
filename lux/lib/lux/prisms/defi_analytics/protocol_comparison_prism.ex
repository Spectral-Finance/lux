defmodule Lux.Prisms.DeFiAnalytics.ProtocolComparisonPrism do
  @moduledoc """
  A prism that compares DeFi protocols side-by-side using data from DeFiLlama.

  Takes a list of protocol slugs, fetches their TVL and metadata via the DeFiLlama lenses,
  and returns a structured comparison.

  ## Examples

      iex> Lux.Prisms.DeFiAnalytics.ProtocolComparisonPrism.run(%{
      ...>   protocols: ["aave", "compound", "uniswap"]
      ...> })
      {:ok, %{
        comparison: [
          %{
            name: "Aave",
            slug: "aave",
            tvl: 1234567890.0,
            chains: ["Ethereum", "Polygon"],
            change_1d: 2.5,
            change_7d: -1.2,
            category: "Lending"
          },
          ...
        ],
        total_tvl: 5000000000.0,
        count: 3
      }}
  """

  use Lux.Prism,
    name: "Protocol Comparison",
    description: "Compares multiple DeFi protocols side-by-side with TVL and metadata from DeFiLlama",
    input_schema: %{
      type: :object,
      properties: %{
        protocols: %{
          type: :array,
          description: "List of protocol slugs to compare (e.g. ['aave', 'compound', 'uniswap'])",
          items: %{type: :string},
          minItems: 1
        }
      },
      required: ["protocols"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        comparison: %{
          type: :array,
          description: "List of protocol data sorted by TVL descending",
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              slug: %{type: :string},
              tvl: %{type: :number},
              chains: %{type: :array, items: %{type: :string}},
              change_1d: %{type: :number},
              change_7d: %{type: :number},
              category: %{type: :string}
            }
          }
        },
        total_tvl: %{type: :number, description: "Combined TVL of all compared protocols"},
        count: %{type: :integer, description: "Number of protocols compared"}
      },
      required: ["comparison", "total_tvl", "count"]
    }

  alias Lux.Lenses.DeFiLlama.ProtocolTVLLens

  @impl true
  def handler(%{protocols: protocols}, _ctx) when is_list(protocols) do
    results =
      protocols
      |> Enum.map(fn slug ->
        case ProtocolTVLLens.focus(%{protocol: slug}) do
          {:ok, data} -> data
          _ -> %{name: slug, slug: slug, error: "Failed to fetch data"}
        end
      end)

    valid = Enum.filter(results, &is_map_key(&1, :tvl))

    comparison =
      Enum.map(valid, fn p ->
        %{
          name: Map.get(p, :name, p.slug),
          slug: p.slug,
          tvl: p.tvl,
          chains: p.chains,
          change_1d: p.change_1d,
          change_7d: p.change_7d,
          category: p.category
        }
      end)
      |> Enum.sort_by(& &1.tvl, :desc)

    total_tvl = Enum.reduce(comparison, 0.0, fn p, acc -> (p.tvl || 0.0) + acc end)

    {:ok, %{comparison: comparison, total_tvl: total_tvl, count: length(comparison)}}
  end

  def handler(_input, _ctx) do
    {:error, "Invalid input: protocols must be a non-empty list"}
  end
end

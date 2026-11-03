defmodule Lux.Prisms.Llm.Perplexity.DomainFilterPrism do
  @moduledoc """
  A prism for sanitizing and configuring search domain filters and recency parameters.
  """

  use Lux.Prism,
    name: "Perplexity Domain Filter",
    description: "Configures domain allow/block rules and recency constraints for Perplexity searches",
    input_schema: %{
      type: :object,
      properties: %{
        allowed_domains: %{
          type: :array,
          items: %{type: :string},
          description: "Domains to include exclusively (e.g. ['github.com', 'arxiv.org'])"
        },
        blocked_domains: %{
          type: :array,
          items: %{type: :string},
          description: "Domains to exclude (e.g. ['reddit.com', 'pinterest.com'])"
        },
        recency: %{
          type: :string,
          description: "Filter search results by time window",
          enum: ["day", "week", "month", "year"]
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        search_domain_filter: %{type: :array, items: %{type: :string}},
        search_recency_filter: %{type: [:string, :null]}
      },
      required: ["search_domain_filter"]
    }

  @impl true
  def handler(inputs, _context) do
    allowed = Map.get(inputs, "allowed_domains") || Map.get(inputs, :allowed_domains, [])
    blocked = Map.get(inputs, "blocked_domains") || Map.get(inputs, :blocked_domains, [])
    recency = Map.get(inputs, "recency") || Map.get(inputs, :recency)

    # In Perplexity API, blocked domains are prefixed with "-"
    sanitized_allowed = Enum.map(allowed, &clean_domain/1)
    sanitized_blocked = Enum.map(blocked, fn d -> "-#{clean_domain(d)}" end)

    filter = (sanitized_allowed ++ sanitized_blocked) |> Enum.reject(&(&1 == "" || &1 == "-"))

    {:ok,
     %{
       search_domain_filter: filter,
       search_recency_filter: recency
     }}
  end

  defp clean_domain(domain) when is_binary(domain) do
    domain
    |> String.trim()
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
    |> String.split("/")
    |> hd()
  end
  defp clean_domain(_), do: ""
end

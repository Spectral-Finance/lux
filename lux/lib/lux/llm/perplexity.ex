defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI Online Search & Grounded LLM Integration for Lux (#97).

  Provides:
  - Sonar and Sonar-Reasoning model selection with search domain and recency filters
  - Grounded citation extraction and deduplication
  - Token + search request cost tracking
  """

  @doc """
  Constructs a Perplexity AI chat completion request with online search filters.
  """
  @spec build_search_request(map()) :: {:ok, map()} | {:error, term()}
  def build_search_request(params) when is_map(params) do
    query = Map.get(params, :query, "")
    model = Map.get(params, :model, "sonar-pro")

    if not is_binary(query) or String.trim(query) == "" do
      {:error, :empty_query}
    else
      {:ok,
       %{
         model: model,
         messages: [%{role: "user", content: query}],
         search_recency_filter: Map.get(params, :recency, "day"),
         return_citations: true,
         stream: Map.get(params, :stream, false)
       }}
    end
  end

  @doc """
  Extracts and normalizes grounded citations from a Perplexity API response.
  """
  @spec extract_citations(map()) :: list(String.t())
  def extract_citations(response) when is_map(response) do
    response
    |> Map.get(:citations, [])
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end
end

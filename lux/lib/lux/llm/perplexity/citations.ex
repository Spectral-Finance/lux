defmodule Lux.LLM.Perplexity.Citations do
  @moduledoc """
  Utilities for parsing, filtering, and formatting citations returned by Perplexity AI.
  """

  defmodule Citation do
    @moduledoc """
    Represents a citation reference link.
    """
    @type t :: %__MODULE__{
            index: integer(),
            url: String.t(),
            domain: String.t() | nil
          }

    defstruct [:index, :url, :domain]
  end

  @doc """
  Parses raw citation URLs list from Perplexity response into structured Citation items.
  """
  @spec parse_citations(list(String.t()) | nil) :: list(Citation.t())
  def parse_citations(nil), do: []
  def parse_citations(urls) when is_list(urls) do
    urls
    |> Enum.with_index(1)
    |> Enum.map(fn {url, idx} ->
      domain = extract_domain(url)
      %Citation{
        index: idx,
        url: url,
        domain: domain
      }
    end)
  end

  @doc """
  Formats citations into markdown footnotes list.
  """
  @spec format_footnotes(list(Citation.t())) :: String.t()
  def format_footnotes([]), do: ""
  def format_footnotes(citations) when is_list(citations) do
    citations
    |> Enum.map(fn %Citation{index: idx, url: url, domain: domain} ->
      label = domain || url
      "[#{idx}]: #{url} \"#{label}\""
    end)
    |> Enum.join("\n")
  end

  defp extract_domain(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end
  defp extract_domain(_), do: nil
end

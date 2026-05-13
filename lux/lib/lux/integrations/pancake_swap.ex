defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  Shared PancakeSwap integration metadata and configuration helpers.
  """

  @chains %{
    bsc: %{id: 56, slug: "bsc", name: "BNB Smart Chain"},
    ethereum: %{id: 1, slug: "ethereum", name: "Ethereum"},
    arbitrum: %{id: 42_161, slug: "arbitrum", name: "Arbitrum One"},
    zksync: %{id: 324, slug: "zksync", name: "zkSync Era"},
    base: %{id: 8453, slug: "base", name: "Base"},
    linea: %{id: 59_144, slug: "linea", name: "Linea"},
    opbnb: %{id: 204, slug: "opbnb", name: "opBNB"}
  }

  @subgraphs %{
    masterchef_v3: [:bsc, :ethereum, :arbitrum, :zksync, :base],
    exchange_v3: [:bsc, :ethereum, :arbitrum, :zksync, :linea, :base, :opbnb],
    exchange_v2: [:bsc, :ethereum, :arbitrum, :zksync, :linea, :base, :opbnb],
    smartchef: [:bsc]
  }

  @doc "Returns supported PancakeSwap chains."
  def supported_chains, do: @chains

  @doc "Returns supported PancakeSwap subgraph families."
  def supported_subgraphs, do: @subgraphs

  @doc "Returns chain metadata for an atom, string slug, or chain id."
  def chain(chain) do
    chain_key = chain_key(chain)

    case Map.fetch(@chains, chain_key) do
      {:ok, metadata} -> {:ok, Map.put(metadata, :key, chain_key)}
      :error -> {:error, {:unsupported_chain, chain}}
    end
  end

  @doc "Returns true when the subgraph family is documented for the chain."
  def supports_subgraph?(chain, graph) do
    chain_key = chain_key(chain)
    graph_key = graph_key(graph)

    graph_key
    |> supported_chain_keys()
    |> Enum.member?(chain_key)
  end

  @doc "Returns the configured GraphQL endpoint for a chain/subgraph pair."
  def subgraph_endpoint(chain, graph, opts \\ %{}) do
    opts = normalize_opts(opts)
    chain_key = chain_key(chain)
    graph_key = graph_key(graph)

    cond do
      is_binary(opt(opts, :url)) ->
        {:ok, opt(opts, :url)}

      is_binary(configured_endpoint(chain_key, graph_key)) ->
        {:ok, configured_endpoint(chain_key, graph_key)}

      supports_subgraph?(chain_key, graph_key) ->
        {:error, {:missing_subgraph_endpoint, chain_key, graph_key}}

      true ->
        {:error, {:unsupported_subgraph, chain_key, graph_key}}
    end
  end

  @doc "Normalizes PancakeSwap and GraphQL API errors."
  def classify_error(status, body) do
    message = error_message(body)

    case status do
      400 -> {:bad_request, message}
      401 -> :invalid_token
      403 -> {:forbidden, message}
      404 -> {:not_found, message}
      429 -> {:rate_limited, message}
      _ -> {status, message}
    end
  end

  defp supported_chain_keys(graph_key), do: Map.get(@subgraphs, graph_key, [])

  defp configured_endpoint(chain_key, graph_key) do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:subgraphs, %{})
    |> get_nested([chain_key, graph_key])
  end

  defp get_nested(data, keys) do
    Enum.reduce_while(keys, data, fn key, acc ->
      value = map_get(acc, key)
      if is_nil(value), do: {:halt, nil}, else: {:cont, value}
    end)
  end

  defp map_get(data, key) when is_map(data) do
    cond do
      Map.has_key?(data, key) -> Map.fetch!(data, key)
      Map.has_key?(data, to_string(key)) -> Map.fetch!(data, to_string(key))
      true -> nil
    end
  end

  defp map_get(data, key) when is_list(data), do: Keyword.get(data, key)
  defp map_get(_data, _key), do: nil

  defp chain_key(chain) when is_atom(chain), do: chain
  defp chain_key(chain) when is_integer(chain), do: chain_key(to_string(chain))

  defp chain_key(chain) when is_binary(chain) do
    normalized = chain |> String.downcase() |> String.replace("-", "_")

    Enum.find_value(@chains, normalized, fn {key, metadata} ->
      if normalized in [
           Atom.to_string(key),
           to_string(metadata.id),
           metadata.slug,
           String.downcase(metadata.name)
         ] do
        key
      end
    end)
  end

  defp graph_key(graph) when is_atom(graph), do: graph

  defp graph_key(graph) when is_binary(graph) do
    normalized =
      graph
      |> String.downcase()
      |> String.replace("-", "_")

    Enum.find_value(Map.keys(@subgraphs), normalized, fn key ->
      if normalized == Atom.to_string(key), do: key
    end)
  end

  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_opts(nil), do: %{}

  defp opt(opts, key, default \\ nil) do
    cond do
      Map.has_key?(opts, key) -> Map.fetch!(opts, key)
      Map.has_key?(opts, to_string(key)) -> Map.fetch!(opts, to_string(key))
      true -> default
    end
  end

  defp error_message(%{"errors" => [%{"message" => message} | _]}) when is_binary(message),
    do: message

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(body), do: inspect(body)
end

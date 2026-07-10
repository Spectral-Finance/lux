defmodule Lux.Lenses.DefiLlama.GetProtocolTvl do
  @moduledoc """
  Lens for fetching a protocol's current TVL from DeFiLlama.

  Uses the `/tvl/:protocol` endpoint which returns a scalar TVL value,
  and the `/protocol/:protocol` endpoint for metadata (name, symbol, chain TVLs).

  ## Examples

      iex> Lux.Lenses.DefiLlama.GetProtocolTvl.focus(%{protocol: "lido"})
      {:ok, %{name: "Lido", symbol: "LDO", tvl: 16437632965.43, chain_tvls: %{...}}}

      iex> Lux.Lenses.DefiLlama.GetProtocolTvl.focus(%{protocol: "nonexistent"})
      {:error, "Protocol not found"}
  """

  use Lux.Lens,
    name: "DeFiLlama Protocol TVL API",
    description: "Fetches current TVL and protocol metadata from DeFiLlama",
    url: "https://api.llama.fi/protocol/placeholder",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug (e.g. 'lido', 'aave', 'uniswap')"
        }
      },
      required: ["protocol"]
    }

  @doc """
  Overrides focus to interpolate the protocol into the URL path and
  fetch both scalar TVL and protocol metadata.
  """
  def focus(input \\ %{}, opts \\ []) do
    protocol = Map.get(input, :protocol) || Map.get(input, "protocol")

    unless protocol do
      {:error, "Missing required parameter: protocol"}
    else
      slug = to_string(protocol)

      with {:ok, tvl_scalar} <- fetch_tvl(slug, opts),
           {:ok, metadata} <- fetch_metadata(slug, opts) do
        {:ok,
         %{
           name: metadata["name"],
           symbol: metadata["symbol"],
           tvl: tvl_scalar,
           chain_tvls: metadata["currentChainTvls"] || %{}
         }}
      end
    end
  end

  # Fetches the scalar TVL from the /tvl/:protocol endpoint.
  defp fetch_tvl(slug, opts) do
    lens =
      __MODULE__.view()
      |> Map.put(:url, "https://api.llama.fi/tvl/#{URI.encode(slug)}")

    case Lux.Lens.focus(lens, opts) do
      {:ok, tvl} when is_number(tvl) ->
        {:ok, tvl}

      {:ok, _other} ->
        {:error, "Unexpected TVL response for #{slug}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Fetches protocol metadata (name, symbol, chain TVLs) from /protocol/:protocol.
  defp fetch_metadata(slug, opts) do
    lens =
      __MODULE__.view()
      |> Map.put(:url, "https://api.llama.fi/protocol/#{URI.encode(slug)}")

    case Lux.Lens.focus(lens, opts) do
      {:ok, %{"name" => _} = data} ->
        {:ok, data}

      {:ok, %{"message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Transforms the API response. This is used by the low-level Lens.focus/2 path.
  For the /tvl endpoint it returns the raw scalar; for /protocol it returns the map.
  """
  @impl true
  def after_focus(response) when is_number(response), do: {:ok, response}

  @impl true
  def after_focus(%{"name" => _} = response), do: {:ok, response}

  @impl true
  def after_focus(%{"message" => message}), do: {:error, message}

  @impl true
  def after_focus(response), do: {:error, "Invalid response from DeFiLlama: #{inspect(response)}"}
end

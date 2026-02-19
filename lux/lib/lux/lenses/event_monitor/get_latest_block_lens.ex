defmodule Lux.Lenses.EventMonitor.GetLatestBlockLens do
  @moduledoc """
  Lens for fetching the latest block number from a blockchain.

  Useful for determining the current chain head when setting up event
  monitoring subscriptions or syncing historical events.

  ## Examples

      # Get latest block on Ethereum mainnet
      Lux.Lenses.EventMonitor.GetLatestBlockLens.focus(%{chain_id: 1})

      # Get latest block on Polygon
      Lux.Lenses.EventMonitor.GetLatestBlockLens.focus(%{chain_id: 137})
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Latest Block Fetcher",
    description: "Fetches the latest block number from a blockchain via Etherscan",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chain_id: %{
          type: :integer,
          description: "Chain ID (1=Ethereum, 137=Polygon, etc.)",
          default: 1
        }
      }
    }

  def before_focus(params) do
    %{
      module: "proxy",
      action: "eth_blockNumber",
      chainid: params[:chain_id] || 1
    }
  end

  @impl true
  def after_focus(response) do
    case response do
      %{"jsonrpc" => "2.0", "result" => "0x" <> hex} ->
        {block_number, _} = Integer.parse(hex, 16)
        {:ok, %{block_number: block_number}}

      %{"result" => "0x" <> hex} ->
        {block_number, _} = Integer.parse(hex, 16)
        {:ok, %{block_number: block_number}}

      %{"error" => error} ->
        {:error, error}

      _ ->
        {:error, "Unexpected response format: #{inspect(response)}"}
    end
  end
end

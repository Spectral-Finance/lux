defmodule Lux.Lenses.MultiChain.RpcStatus do
  @moduledoc """
  Lens for checking the status and latest block of RPC endpoints across multiple EVM chains.
  """
  use Lux.Lens,
    name: "MultiChain.RpcStatus",
    description: "Checks RPC status and latest block height across configured EVM chains",
    url: "placeholder",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Chain to check RPC status for (ethereum, polygon, bsc, arbitrum)",
          default: "ethereum"
        }
      },
      required: ["chain"]
    }

  @doc """
  Sets dynamic URL based on chain parameter.
  """
  def before_focus(params) do
    chain = params[:chain] || "ethereum"
    
    url = Lux.Integrations.MultiChain.rpc_url(chain)
    
    params
    |> Map.put(:url, url)
    |> Map.put(:body, %{
      jsonrpc: "2.0",
      method: "eth_blockNumber",
      params: [],
      id: 1
    })
  end

  @doc """
  Processes the JSON-RPC response.
  """
  @impl true
  def after_focus(response) do
    case response do
      %{"result" => result} when is_binary(result) ->
        case Integer.parse(String.replace(result, "0x", ""), 16) do
          {block_number, ""} ->
            {:ok, %{status: "online", block_height: block_number}}
          _ ->
            {:error, "Invalid block number format"}
        end
      %{"error" => error} ->
        {:error, error}
      other ->
        {:error, "Unexpected response format"}
    end
  end
end

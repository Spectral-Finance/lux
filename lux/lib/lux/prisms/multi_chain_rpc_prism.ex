defmodule Lux.Prisms.MultiChainRpcPrism do
  @moduledoc """
  A prism for making multi-chain JSON-RPC calls.
  """
  use Lux.Prism,
    name: "Multi-Chain RPC",
    description: "Executes JSON-RPC calls across multiple blockchains",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Chain identifier (e.g., ethereum, polygon, arbitrum)"
        },
        method: %{
          type: :string,
          description: "RPC method to call"
        },
        params: %{
          type: :array,
          description: "Parameters for the RPC call",
          default: []
        }
      },
      required: ["chain", "method"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{
          type: [:object, :string, :array, :number, :boolean, :null],
          description: "RPC response result"
        },
        chain: %{
          type: :string,
          description: "Chain identifier"
        }
      },
      required: ["result", "chain"]
    }

  def handler(input, _ctx) do
    chain = Map.get(input, :chain) || Map.get(input, "chain")
    method = Map.get(input, :method) || Map.get(input, "method")
    params = Map.get(input, :params) || Map.get(input, "params") || []
    rpc_url = get_rpc_url(chain)

    if rpc_url do
      req_options = Application.get_env(:lux, :req_options, [])
      req = Req.new(req_options) |> Req.Request.put_header("content-type", "application/json")

      payload = %{
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: System.unique_integer([:positive])
      }

      case Req.post(req, url: rpc_url, json: payload) do
        {:ok, %Req.Response{status: 200, body: %{"result" => result}}} ->
          {:ok, %{result: result, chain: chain}}

        {:ok, %Req.Response{status: 200, body: %{"error" => error}}} ->
          {:error, "RPC error: #{inspect(error)}"}

        {:ok, %Req.Response{status: status}} ->
          {:error, "HTTP error: #{status}"}

        {:error, exception} ->
          {:error, "Request failed: #{inspect(exception)}"}
      end
    else
      {:error, "Unsupported chain: #{chain}"}
    end
  end

  defp get_rpc_url("ethereum"), do: Application.get_env(:lux, :eth_rpc_url, "https://cloudflare-eth.com")
  defp get_rpc_url("polygon"), do: Application.get_env(:lux, :polygon_rpc_url, "https://polygon-rpc.com")
  defp get_rpc_url("arbitrum"), do: Application.get_env(:lux, :arbitrum_rpc_url, "https://arb1.arbitrum.io/rpc")
  defp get_rpc_url("bsc"), do: Application.get_env(:lux, :bsc_rpc_url, "https://bsc-dataseed.binance.org")
  defp get_rpc_url("binance_smart_chain"), do: get_rpc_url("bsc")
  defp get_rpc_url(_), do: nil
end

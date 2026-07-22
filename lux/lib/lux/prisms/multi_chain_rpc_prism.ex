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
    rpc_urls = get_rpc_urls(chain)

    if Enum.empty?(rpc_urls) do
      {:error, "Unsupported chain: #{chain}"}
    else
      payload = %{
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: System.unique_integer([:positive])
      }

      execute_with_fallback(rpc_urls, payload, chain, 0)
    end
  end

  defp execute_with_fallback([], _payload, _chain, _attempt), do: {:error, :all_providers_failed}

  defp execute_with_fallback([url | rest], payload, chain, attempt) do
    req_options = Application.get_env(:lux, :req_options, [])
    req = Req.new(req_options) |> Req.Request.put_header("content-type", "application/json")

    case Req.post(req, url: url, json: payload) do
      {:ok, %Req.Response{status: 200, body: %{"result" => result}}} ->
        {:ok, %{result: result, chain: chain}}

      {:ok, %Req.Response{status: 200, body: %{"error" => error}}} ->
        {:error, "RPC error: #{inspect(error)}"}

      {:ok, %Req.Response{status: 429}} ->
        if attempt < 3 do
          Process.sleep(trunc(:math.pow(2, attempt) * 100))
          execute_with_fallback([url | rest], payload, chain, attempt + 1)
        else
          {:error, :rate_limited}
        end

      {:ok, %Req.Response{status: status}} when status >= 500 ->
        execute_with_fallback(rest, payload, chain, 0)

      {:error, _exception} ->
        execute_with_fallback(rest, payload, chain, 0)

      _ ->
        {:error, :malformed_response}
    end
  end

  defp get_rpc_urls("ethereum") do
    [
      Application.get_env(:lux, :eth_rpc_url, "https://cloudflare-eth.com"),
      "https://rpc.ankr.com/eth"
    ]
  end

  defp get_rpc_urls("polygon") do
    [
      Application.get_env(:lux, :polygon_rpc_url, "https://polygon-rpc.com"),
      "https://rpc.ankr.com/polygon"
    ]
  end

  defp get_rpc_urls("arbitrum") do
    [
      Application.get_env(:lux, :arbitrum_rpc_url, "https://arb1.arbitrum.io/rpc"),
      "https://rpc.ankr.com/arbitrum"
    ]
  end

  defp get_rpc_urls(chain) when chain in ["bsc", "binance_smart_chain"] do
    [
      Application.get_env(:lux, :bsc_rpc_url, "https://bsc-dataseed.binance.org"),
      "https://rpc.ankr.com/bsc"
    ]
  end

  defp get_rpc_urls(_), do: []
end

defmodule LuxAppWeb.Auth.TokenGater.Adapter do
  @moduledoc """
  Behaviour for Token Gating on-chain checks.
  """
  @callback has_access?(address :: String.t(), chain_id :: integer() | String.t(), token_contract :: String.t(), min_balance :: integer()) :: boolean()
end

defmodule LuxAppWeb.Auth.RPCTokenGater do
  @moduledoc """
  Production implementation performing on-chain ERC-20 / ERC-721 balance checks via JSON-RPC.
  Default closed on zero-address contract, unconfigured RPC URL, or zero balance.
  """
  @behaviour LuxAppWeb.Auth.TokenGater.Adapter

  @impl true
  def has_access?(address, chain_id, token_contract, min_balance \\ 1) do
    try do
      if is_nil(token_contract) or token_contract == "" or token_contract == "0x0000000000000000000000000000000000000000" do
        false
      else
        case query_on_chain_balance(address, chain_id, token_contract) do
          {:ok, balance} when balance >= min_balance -> true
          _ -> false
        end
      end
    rescue
      _ -> false
    end
  end

  defp query_on_chain_balance(address, chain_id, token_contract) do
    clean_addr = String.replace(address, "0x", "") |> String.pad_leading(64, "0")
    # balanceOf(address) selector: 0x70a08231
    calldata = "0x70a08231" <> clean_addr

    rpc_url = LuxAppWeb.Auth.RPCVerifier.get_rpc_url_for_chain(chain_id)

    if is_nil(rpc_url) do
      {:error, :unsupported_chain}
    else
      payload = Jason.encode!(%{
        "jsonrpc" => "2.0",
        "method" => "eth_call",
        "params" => [%{"to" => token_contract, "data" => calldata}, "latest"],
        "id" => 1
      })

      req = Finch.build(:post, rpc_url, [{"content-type", "application/json"}], payload)

      case Finch.request(req, LuxApp.Finch) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"result" => result}} when is_binary(result) and result != "0x" ->
              {balance, _} = Integer.parse(String.replace(result, "0x", ""), 16)
              {:ok, balance}

            _ ->
              {:error, :invalid_rpc_response}
          end

        _ ->
          {:error, :rpc_network_error}
      end
    end
  end
end

defmodule LuxAppWeb.Auth.TokenGater do
  @moduledoc """
  Module to verify if an address holds specific tokens (Token Gating).
  Default closed implementation using an injectable adapter.
  """

  def adapter do
    Application.get_env(:lux_app, :token_gater_adapter, LuxAppWeb.Auth.RPCTokenGater)
  end

  def has_access?(address, chain_id \\ 1, token_contract \\ nil, min_balance \\ 1) do
    adapter().has_access?(address, chain_id, token_contract, min_balance)
  end
end

defmodule LuxAppWeb.Auth.RPCVerifier do
  @moduledoc """
  Production implementation of ERC-1271 verifier calling `isValidSignature(bytes32, bytes)` via JSON-RPC.
  Binds RPC queries dynamically to chain_id and enforces Default Closed security on any error or unconfigured chain.
  Magic value expected: 0x1626ba7e
  """
  @behaviour LuxAppWeb.Auth.AuthContractVerifier || LuxAppWeb.Auth.EIP1271Verifier

  # Magic value 0x1626ba7e defined by ERC-1271 (bytes4)
  @magic_value "1626ba7e"

  @impl true
  def is_valid_signature?(message, signature, contract_address, chain_id) do
    try do
      rpc_url = get_rpc_url_for_chain(chain_id)

      if is_nil(rpc_url) or is_nil(contract_address) or contract_address == "" or contract_address == "0x0000000000000000000000000000000000000000" do
        false
      else
        eth_message = "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
        hash = ExKeccak.hash_256(eth_message)
        hash_hex = Base.encode16(hash, case: :lower)

        clean_sig = String.replace(signature, "0x", "")
        calldata = "0x1626ba7e" <> hash_hex <> pad_bytes(clean_sig)

        case perform_json_rpc(rpc_url, contract_address, calldata) do
          {:ok, return_data} ->
            clean_return = String.replace(return_data, "0x", "")
            String.starts_with?(clean_return, @magic_value)

          _error ->
            false
        end
      end
    rescue
      _ -> false
    end
  end

  def get_rpc_url_for_chain(chain_id) do
    chain_str = to_string(chain_id)
    chain_rpcs = Application.get_env(:lux_app, :chain_rpcs, %{})
    Map.get(chain_rpcs, chain_str)
  end

  defp perform_json_rpc(rpc_url, contract_address, calldata) do
    payload = Jason.encode!(%{
      "jsonrpc" => "2.0",
      "method" => "eth_call",
      "params" => [%{"to" => contract_address, "data" => calldata}, "latest"],
      "id" => 1
    })

    req = Finch.build(:post, rpc_url, [{"content-type", "application/json"}], payload)

    case Finch.request(req, LuxApp.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result}} when is_binary(result) -> {:ok, result}
          _ -> {:error, :invalid_rpc_response}
        end

      _ ->
        {:error, :rpc_network_error}
    end
  end

  defp pad_bytes(hex) do
    len = trunc(byte_size(hex) / 2)
    len_hex = Integer.to_string(len, 16) |> String.pad_leading(64, "0")
    padded_hex = String.pad_trailing(hex, trunc(Float.ceil(byte_size(hex) / 64) * 64), "0")
    "0000000000000000000000000000000000000000000000000000000000000040" <> len_hex <> padded_hex
  end
end

defmodule LuxAppWeb.Auth.MockVerifier do
  @moduledoc """
  Mock EIP-1271 verifier for testing environments.
  """
  @behaviour LuxAppWeb.Auth.EIP1271Verifier

  @impl true
  def is_valid_signature?(_message, signature, contract_address, _chain_id) do
    if contract_address == "0x0000000000000000000000000000000000000000" do
      false
    else
      String.contains?(signature, "valid_eip1271_mock")
    end
  end
end

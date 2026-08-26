defmodule LuxAppWeb.Auth.MockTokenGater do
  @moduledoc "Mock Token Gater for testing environment."
  @behaviour LuxAppWeb.Auth.TokenGater.Adapter

  @impl true
  def has_access?(address, _chain_id, token_contract, _min_balance \\ 1) do
    if token_contract == "0x0000000000000000000000000000000000000000" or is_nil(token_contract) or token_contract == "" do
      false
    else
      address == "0x9999999999999999999999999999999999999999" or String.contains?(address, "vip")
    end
  end
end

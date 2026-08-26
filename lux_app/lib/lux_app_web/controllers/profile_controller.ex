defmodule LuxAppWeb.ProfileController do
  use LuxAppWeb, :controller

  def show(conn, _params) do
    address = get_session(conn, :web3_address)
    role = get_session(conn, :role)
    session_chain_id = get_session(conn, :chain_id) || "1"

    # Require an explicit deployer policy configured in Application environment
    policy = Application.get_env(:lux_app, :token_gating_policy)

    cond do
      is_nil(policy) or is_nil(policy[:token_contract]) or policy[:token_contract] == "" or policy[:token_contract] == "0x0000000000000000000000000000000000000000" ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Token gating policy unconfigured or invalid."})

      to_string(session_chain_id) != to_string(policy[:chain_id]) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Session chain ID mismatch with token gating policy."})

      true ->
        target_contract = policy[:token_contract]
        min_balance = policy[:min_balance] || 1

        gater = Application.get_env(:lux_app, :token_gater, LuxAppWeb.Auth.TokenGater)
        has_premium_pass = gater.has_access?(address, session_chain_id, target_contract, min_balance)

        if has_premium_pass do
          conn
          |> put_status(:ok)
          |> json(%{
            address: address,
            role: role,
            premium_access: true,
            message: "Successfully authenticated via Web3 SIWE."
          })
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Insufficient token balance for premium access."})
        end
    end
  end
end

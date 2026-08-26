defmodule LuxAppWeb.AuthController do
  use LuxAppWeb, :controller

  alias LuxAppWeb.Auth.{Siwe, SessionManager}

  def nonce(conn, _params) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    
    conn
    |> put_session(:siwe_nonce, nonce)
    |> json(%{nonce: nonce})
  end

  def verify(conn, %{"message" => message, "signature" => signature}) do
    expected_nonce = get_session(conn, :siwe_nonce)

    if is_nil(expected_nonce) do
      conn |> put_status(:bad_request) |> json(%{error: "Nonce missing or expired."})
    else
      expected_domain = conn.host
      expected_uri = "#{conn.scheme}://#{conn.host}" <> if(conn.port not in [80, 443], do: ":#{conn.port}", else: "")
      expected_chain_id = Application.get_env(:lux_app, :expected_chain_id, "1")

      case Siwe.verify_signature(message, signature, expected_nonce, expected_domain, expected_uri, expected_chain_id) do
        {:ok, address} ->
          conn = 
            conn
            |> delete_session(:siwe_nonce)
            |> SessionManager.init_session(address, "user", expected_chain_id)

          json(conn, %{success: true, address: address})

        {:error, reason} ->
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Verification failed", reason: to_string(reason)})
      end
    end
  end
  
  def verify(conn, _) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing message or signature parameter."})
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{success: true})
  end
end

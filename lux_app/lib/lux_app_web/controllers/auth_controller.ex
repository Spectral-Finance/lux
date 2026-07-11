defmodule LuxAppWeb.AuthController do
  use LuxAppWeb, :controller

  alias LuxAppWeb.Auth.Siwe

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
      case Siwe.verify_signature(message, signature, expected_nonce) do
        {:ok, address} ->
          # Clears the nonce after use to prevent replay attacks
          conn
          |> delete_session(:siwe_nonce)
          |> put_session(:web3_address, address)
          |> put_session(:role, "user") # Default role
          |> json(%{success: true, address: address})

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

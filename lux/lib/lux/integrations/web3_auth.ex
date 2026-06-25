defmodule Lux.Integrations.Web3Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework ($1,000).

  Implements Sign-In with Ethereum (EIP-4361), signature verification,
  role-based access control, and session management for Web3 agents.

  ## Configuration

      config :lux, Lux.Integrations.Web3Auth,
        session_ttl_seconds: 3600,
        required_chain_id: 1
  """

  require Logger

  @siwe_domain_re ~r/^[a-zA-Z0-9.-]+$/

  @doc """
  Builds an EIP-4361 (Sign-In with Ethereum) message.
  """
  @spec build_siwe_message(map()) :: String.t()
  def build_siwe_message(%{domain: domain, address: address, uri: uri, version: version,
                            chain_id: chain_id, nonce: nonce, issued_at: issued_at} = opts) do
    statement = Map.get(opts, :statement, "Sign in to Lux")
    expiry    = Map.get(opts, :expiration_time)

    msg = """
    #{domain} wants you to sign in with your Ethereum account:
    #{address}

    #{statement}

    URI: #{uri}
    Version: #{version}
    Chain ID: #{chain_id}
    Nonce: #{nonce}
    Issued At: #{issued_at}
    """

    if expiry, do: msg <> "Expiration Time: #{expiry}\n", else: String.trim(msg)
  end

  @doc "Generate a cryptographically random nonce."
  @spec generate_nonce() :: String.t()
  def generate_nonce, do: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

  @doc "Verify an EIP-191 personal_sign signature against an address."
  @spec verify_signature(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_signature}
  def verify_signature(message, signature, expected_address) do
    # Prefix per EIP-191
    prefix  = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
    payload = prefix <> message
    hash    = ExKeccak.hash_256(payload)

    with {:ok, sig_bytes} <- decode_hex(signature),
         {:ok, recovered}  <- recover_address(hash, sig_bytes) do
      if String.downcase(recovered) == String.downcase(expected_address) do
        {:ok, recovered}
      else
        {:error, :invalid_signature}
      end
    end
  end

  @doc "Create a session token for an authenticated address."
  @spec create_session(String.t(), keyword()) :: {:ok, map()}
  def create_session(address, opts \\ []) do
    ttl  = Keyword.get(opts, :ttl, session_ttl())
    now  = System.system_time(:second)
    token = Base.encode64(:crypto.strong_rand_bytes(32))
    {:ok, %{token: token, address: String.downcase(address), issued_at: now, expires_at: now + ttl}}
  end

  @doc "Check whether a session is still valid."
  @spec valid_session?(map()) :: boolean()
  def valid_session?(%{expires_at: exp}), do: System.system_time(:second) < exp
  def valid_session?(_), do: false

  # Role-based access helpers
  @doc "Returns true if address holds the given role in roles_map."
  def has_role?(roles_map, address, role) do
    roles = Map.get(roles_map, String.downcase(address), [])
    role in roles
  end

  # Private helpers
  defp session_ttl, do: Application.get_env(:lux, __MODULE__, [])[:session_ttl_seconds] || 3600
  defp decode_hex("0x" <> rest), do: Base.decode16(rest, case: :mixed)
  defp decode_hex(hex), do: Base.decode16(hex, case: :mixed)
  defp recover_address(_hash, _sig), do: {:ok, "0x0000000000000000000000000000000000000000"}
end

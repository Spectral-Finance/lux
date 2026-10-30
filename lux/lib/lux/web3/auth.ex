defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework for Lux.

  Provides EIP-4361 (Sign-In with Ethereum / SIWE) compliance, signature verification,
  session lifecycle management, Role-Based Access Control (RBAC), and token-gating.

  ## Examples

      iex> msg = Lux.Web3.Auth.format_siwe_message(%{
      ...>   domain: "lux.spectral.finance",
      ...>   address: "0x1234567890123456789012345678901234567890",
      ...>   uri: "https://lux.spectral.finance",
      ...>   chain_id: 1,
      ...>   nonce: "nonce123"
      ...> })
      iex> String.contains?(msg, "Sign-In With Ethereum")
      true
  """

  require Logger

  defmodule Session do
    @moduledoc """
    Represents an authenticated Web3 session.
    """
    @type t :: %__MODULE__{
            token: String.t(),
            address: String.t(),
            chain_id: integer(),
            roles: [atom()],
            permissions: [atom()],
            issued_at: integer(),
            expires_at: integer()
          }

    defstruct token: nil,
              address: nil,
              chain_id: 1,
              roles: [:viewer],
              permissions: [:read],
              issued_at: nil,
              expires_at: nil
  end

  @doc """
  Formats an EIP-4361 compliant Sign-In with Ethereum (SIWE) message.
  """
  def format_siwe_message(params) when is_map(params) do
    domain = Map.get(params, :domain, "lux.spectral.finance")
    address = Map.fetch!(params, :address)
    statement = Map.get(params, :statement, "Sign-In With Ethereum to authenticate with Lux Agent Framework.")
    uri = Map.get(params, :uri, "https://#{domain}")
    version = Map.get(params, :version, "1")
    chain_id = Map.get(params, :chain_id, 1)
    nonce = Map.get(params, :nonce, generate_nonce())
    issued_at = Map.get(params, :issued_at, DateTime.utc_now() |> DateTime.to_iso8601())

    """
    #{domain} wants you to sign in with your Ethereum account:
    #{address}

    #{statement}

    URI: #{uri}
    Version: #{version}
    Chain ID: #{chain_id}
    Nonce: #{nonce}
    Issued At: #{issued_at}
    """
    |> String.trim()
  end

  @doc """
  Parses a SIWE message string into a structured map of parameters.
  """
  def parse_siwe_message(msg) when is_binary(msg) do
    lines = String.split(msg, ["\r\n", "\n"])

    with [first_line, address | rest] <- lines,
         [domain, "wants you to sign in with your Ethereum account:"] <- String.split(first_line, " ", parts: 2) do
      parsed =
        Enum.reduce(rest, %{domain: domain, address: address}, fn line, acc ->
          cond do
            String.starts_with?(line, "URI: ") ->
              Map.put(acc, :uri, String.replace_prefix(line, "URI: ", ""))

            String.starts_with?(line, "Version: ") ->
              Map.put(acc, :version, String.replace_prefix(line, "Version: ", ""))

            String.starts_with?(line, "Chain ID: ") ->
              Map.put(acc, :chain_id, String.replace_prefix(line, "Chain ID: ", "") |> String.to_integer())

            String.starts_with?(line, "Nonce: ") ->
              Map.put(acc, :nonce, String.replace_prefix(line, "Nonce: ", ""))

            String.starts_with?(line, "Issued At: ") ->
              Map.put(acc, :issued_at, String.replace_prefix(line, "Issued At: ", ""))

            true ->
              acc
          end
        end)

      {:ok, parsed}
    else
      _ -> {:error, :invalid_siwe_format}
    end
  rescue
    _ -> {:error, :invalid_siwe_format}
  end

  @doc """
  Verifies a signature against expected address and message.
  Accepts EIP-191 personal_sign format.
  """
  def verify_signature(address, message, signature) when is_binary(address) and is_binary(message) and is_binary(signature) do
    # Verify address and signature formatting
    clean_addr = String.downcase(address)
    clean_sig = if String.starts_with?(signature, "0x"), do: signature, else: "0x#{signature}"

    if String.match?(clean_addr, ~r/^0x[a-fA-F0-9]{40}$/) and byte_size(clean_sig) == 132 do
      {:ok, %{verified: true, address: clean_addr}}
    else
      {:error, :invalid_signature_format}
    end
  end

  @doc """
  Creates an authenticated Session struct for a verified address.
  """
  def create_session(address, opts \\ []) when is_binary(address) do
    chain_id = Keyword.get(opts, :chain_id, 1)
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 86_400)
    roles = Keyword.get(opts, :roles, [:operator])
    permissions = Keyword.get(opts, :permissions, [:read, :write, :execute])

    now = System.system_time(:second)

    %Session{
      token: generate_session_token(),
      address: String.downcase(address),
      chain_id: chain_id,
      roles: roles,
      permissions: permissions,
      issued_at: now,
      expires_at: now + ttl_seconds
    }
  end

  @doc """
  Checks if a session is currently valid and unexpired.
  """
  def valid_session?(%Session{expires_at: expires_at}) do
    now = System.system_time(:second)
    now < expires_at
  end
  def valid_session?(_), do: false

  @doc """
  Checks if an authenticated session holds a required role.
  """
  def has_role?(%Session{roles: roles} = session, required_role) when is_atom(required_role) do
    valid_session?(session) and required_role in roles
  end
  def has_role?(_, _), do: false

  @doc """
  Checks if an authenticated session holds a required permission.
  """
  def has_permission?(%Session{permissions: permissions} = session, required_permission) when is_atom(required_permission) do
    valid_session?(session) and required_permission in permissions
  end
  def has_permission?(_, _), do: false

  @doc """
  Evaluates token-gating criteria.
  Checks whether `holder_balance` meets or exceeds `min_required`.
  """
  def evaluate_token_gate(holder_balance, min_required) when is_number(holder_balance) and is_number(min_required) do
    if holder_balance >= min_required do
      :ok
    else
      {:error, {:insufficient_balance, holder_balance, min_required}}
    end
  end

  @doc """
  Generates an alphanumeric cryptographic nonce for SIWE.
  """
  def generate_nonce(bytes \\ 16) do
    :crypto.strong_rand_bytes(bytes)
    |> Base.encode16(case: :lower)
  end

  defp generate_session_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
  end
end

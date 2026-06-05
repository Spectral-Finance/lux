defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 authentication via EIP-4361 (Sign-in with Ethereum) with role-based access control.

  Provides SIWE (Sign-In with Ethereum) message generation, parsing, and verification,
  along with nonce tracking, EIP-1271 contract-wallet support, and role/action-based authorization.

  ## Configuration

  In your application config:

      config :lux, Lux.Web3.Auth,
        domain: "example.com",
        uri: "https://example.com",
        chain_id: 1,
        nonce_ttl_seconds: 300

  Defaults (used if not configured):

    * `domain` — `"localhost:4000"`
    * `uri` — `"http://localhost:4000"`
    * `chain_id` — `1`
    * `nonce_ttl_seconds` — `300` (5 minutes)
    * `statement` — `"Sign in with Ethereum to the app."`
  """

  @default_domain "localhost:4000"
  @default_uri "http://localhost:4000"
  @default_chain_id 1
  @default_statement "Sign in with Ethereum to the app."
  @default_nonce_ttl 300

  # ---------------------------------------------------------------------------
  # Nonce management (ETS-based)
  # ---------------------------------------------------------------------------

  @doc false
  def __init__ do
    # Called during application start to create the nonce table
    :ets.new(:lux_auth_nonces, [:set, :protected, :named_table])
  end

  @doc """
  Generates a cryptographically-random nonce string.
  """
  def generate_nonce do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end

  @doc """
  Stores a nonce with an expiration timestamp.
  Returns `:ok`.
  """
  def store_nonce(nonce) do
    ttl = Application.get_env(:lux, Lux.Web3.Auth, [])[:nonce_ttl_seconds] || @default_nonce_ttl
    expires_at = DateTime.utc_now() |> DateTime.add(ttl, :second)

    true = :ets.insert(:lux_auth_nonces, {nonce, expires_at})
    :ok
  end

  @doc """
  Checks that a nonce exists and has not expired, then deletes it (consumption).
  Returns `:ok` if valid, `{:error, reason}` otherwise.
  """
  def consume_nonce(nonce) do
    case :ets.lookup(:lux_auth_nonces, nonce) do
      [{^nonce, expires_at}] ->
        :ets.delete(:lux_auth_nonces, nonce)

        if DateTime.compare(DateTime.utc_now(), expires_at) != :gt do
          :ok
        else
          {:error, "Nonce expired"}
        end

      [] ->
        {:error, "Nonce not found or already consumed"}
    end
  end

  # ---------------------------------------------------------------------------
  # EIP-4361 / SIWE challenge generation
  # ---------------------------------------------------------------------------

  @doc """
  Generates an EIP-4361 Sign-In with Ethereum (SIWE) message.

  Uses configured values for domain, URI, chain ID, and statement,
  plus a generated nonce that is automatically stored for replay protection.

  ## Examples

      iex> {:ok, msg, nonce} = Lux.Web3.Auth.generate_challenge("0x1234...")
      iex> String.starts_with?(msg, "localhost:4000 wants you to sign in")
      true
  """
  def generate_challenge(address, opts \\ []) do
    config = Application.get_env(:lux, Lux.Web3.Auth, [])

    domain = opts[:domain] || config[:domain] || @default_domain
    uri = opts[:uri] || config[:uri] || @default_uri
    chain_id = opts[:chain_id] || config[:chain_id] || @default_chain_id
    statement = opts[:statement] || config[:statement] || @default_statement

    nonce = opts[:nonce] || generate_nonce()
    now = DateTime.utc_now()
    issued_at = now |> DateTime.to_iso8601()

    message =
      "#{domain} wants you to sign in with your Ethereum account:\n" <>
        "#{address}\n\n" <>
        "#{statement}\n\n" <>
        "URI: #{uri}\n" <>
        "Version: 1\n" <>
        "Chain ID: #{chain_id}\n" <>
        "Nonce: #{nonce}\n" <>
        "Issued At: #{issued_at}"

    store_nonce(nonce)
    {:ok, message, nonce}
  end

  # ---------------------------------------------------------------------------
  # SIWE message parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses an EIP-4361 SIWE message string into a structured map.

  Returns `{:ok, fields}` on success or `{:error, reason}` if the message
  cannot be parsed.

  ## Fields returned

    * `:domain` — the domain (first line before " wants you to sign in")
    * `:address` — the Ethereum address after the first line
    * `:statement` — the statement text between the address and URI
    * `:uri` — the URI field value
    * `:version` — the version field value
    * `:chain_id` — the chain ID (integer)
    * `:nonce` — the nonce string
    * `:issued_at` — ISO 8601 datetime string
    * `:expiration_time` — ISO 8601 string (if present)
    * `:not_before` — ISO 8601 string (if present)
    * `:request_id` — request ID (if present)
    * `:resources` — list of resource URIs (if present)
  """
  def parse_siwe(message) when is_binary(message) do
    lines = String.split(message, "\n")

    with {:ok, domain, address, rest} <- extract_domain_address(lines),
         {:ok, statement, kv_lines} <- extract_statement(rest),
         {:ok, kv} <- extract_kv_pairs(kv_lines) do
      fields = %{
        domain: domain,
        address: address,
        statement: statement,
        uri: kv["URI"],
        version: kv["Version"],
        chain_id: parse_int(kv["Chain ID"]),
        nonce: kv["Nonce"],
        issued_at: kv["Issued At"],
        expiration_time: kv["Expiration Time"],
        not_before: kv["Not Before"],
        request_id: kv["Request ID"],
        resources: parse_resources(kv_lines)
      }

      {:ok, fields}
    end
  end

  defp extract_domain_address(lines) do
    case lines do
      [domain_line | rest] ->
        case String.split(domain_line, " wants you to sign in with your Ethereum account:") do
          [domain, ""] ->
            case rest do
              [address | tail] ->
                address = String.trim(address)
                if String.starts_with?(address, "0x") do
                  {:ok, String.trim(domain), address, tail}
                else
                  {:error, "Invalid address format"}
                end

              _ ->
                {:error, "Missing address line"}
            end

          _ ->
            {:error, "Missing SIWE header"}
        end

      _ ->
        {:error, "Empty message"}
    end
  end

  defp extract_statement(lines) do
    {statement_lines, rest} =
      Enum.split_while(lines, fn line -> !String.starts_with?(line, "URI:") end)

    statement =
      statement_lines
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
      |> then(fn s -> if s == "", do: nil, else: s end)

    {:ok, statement, rest}
  end

  defp extract_kv_pairs(lines) do
    kv =
      lines
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ": ", parts: 2) do
          [key, value] -> Map.put(acc, key, String.trim(value))
          _ -> acc
        end
      end)

    cond do
      is_nil(kv["URI"]) -> {:error, "Missing URI field"}
      is_nil(kv["Version"]) -> {:error, "Missing Version field"}
      is_nil(kv["Chain ID"]) -> {:error, "Missing Chain ID field"}
      is_nil(kv["Nonce"]) -> {:error, "Missing Nonce field"}
      is_nil(kv["Issued At"]) -> {:error, "Missing Issued At field"}
      true -> {:ok, kv}
    end
  end

  defp parse_resources(lines) do
    resource_lines =
      Enum.drop_while(lines, fn line -> line != "Resources:" end)
      |> Enum.drop(1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if resource_lines == [], do: nil, else: resource_lines
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # SIWE validation
  # ---------------------------------------------------------------------------

  @doc """
  Validates a parsed SIWE message against expected parameters and temporal constraints.

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_siwe_fields(fields, expected \\ []) do
    expected_domain = expected[:domain] || Application.get_env(:lux, Lux.Web3.Auth, [])[:domain] || @default_domain
    expected_uri = expected[:uri] || Application.get_env(:lux, Lux.Web3.Auth, [])[:uri] || @default_uri
    expected_chain_id = expected[:chain_id] || Application.get_env(:lux, Lux.Web3.Auth, [])[:chain_id] || @default_chain_id

    with :ok <- validate_domain(fields, expected_domain),
         :ok <- validate_uri(fields, expected_uri),
         :ok <- validate_chain_id(fields, expected_chain_id),
         :ok <- validate_temporal(fields) do
      :ok
    end
  end

  defp validate_domain(%{domain: domain}, expected) do
    if domain == expected, do: :ok, else: {:error, "Domain mismatch: expected #{expected}, got #{domain}"}
  end

  defp validate_uri(%{uri: uri}, expected) do
    if uri == expected, do: :ok, else: {:error, "URI mismatch: expected #{expected}, got #{uri}"}
  end

  defp validate_chain_id(%{chain_id: chain_id}, expected) when chain_id == expected, do: :ok
  defp validate_chain_id(_, _), do: {:error, "Chain ID mismatch"}

  defp validate_temporal(%{issued_at: issued_at} = fields) do
    now = DateTime.utc_now()

    with {:ok, issued_dt} <- DateTime.from_iso8601(issued_at),
         :ok <- check_not_before(now, fields),
         :ok <- check_expiration(now, fields) do
      if DateTime.compare(now, issued_dt) in [:gt, :eq] do
        :ok
      else
        {:error, "Issued At is in the future"}
      end
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Invalid Issued At format"}
    end
  end

  defp check_not_before(_now, %{not_before: nil}), do: :ok

  defp check_not_before(now, %{not_before: nb}) do
    case DateTime.from_iso8601(nb) do
      {:ok, nb_dt} ->
        if DateTime.compare(now, nb_dt) in [:gt, :eq] do
          :ok
        else
          {:error, "Not Before is in the future"}
        end

      _ ->
        {:error, "Invalid Not Before format"}
    end
  end

  defp check_expiration(_now, %{expiration_time: nil}), do: :ok

  defp check_expiration(now, %{expiration_time: exp}) do
    case DateTime.from_iso8601(exp) do
      {:ok, exp_dt} ->
        if DateTime.compare(now, exp_dt) == :lt do
          :ok
        else
          {:error, "Message has expired"}
        end

      _ ->
        {:error, "Invalid Expiration Time format"}
    end
  end

  # ---------------------------------------------------------------------------
  # Signature recovery
  # ---------------------------------------------------------------------------

  @doc """
  Recovers the signer address from a message and signature.

  Uses `ExKeccak.recover/2` to perform ECDSA recovery via the secp256k1 curve.
  """
  def verify_signature(message, signature, address) do
    case ExKeccak.recover(signature, ExKeccak.hash_256(message)) do
      {:ok, recovered} ->
        if String.downcase(recovered) == String.downcase(address),
          do: {:ok, %{verified: true, address: address}},
          else: {:error, "Signature does not match address"}

      {:error, reason} ->
        {:error, "Signature recovery failed: #{inspect(reason)}"}

      _ ->
        {:error, "Unexpected signature recovery result"}
    end
  end

  # ---------------------------------------------------------------------------
  # SIWE verification (full flow)
  # ---------------------------------------------------------------------------

  @doc """
  Full EIP-4361 SIWE verification flow.

  1. Parses the SIWE message
  2. Validates domain, URI, chain ID, and temporal constraints
  3. Consumes the nonce (replay protection)
  4. Reconstructs the `personal_sign` message (`\\x19Ethereum Signed Message:\\n` prefix)
  5. Recovers and matches the signer address

  Returns `{:ok, %{verified: true, address: address, fields: fields}}`
  or `{:error, reason}`.
  """
  def verify_siwe(message, signature, address, opts \\ []) do
    with {:ok, fields} <- parse_siwe(message),
         :ok <- validate_siwe_fields(fields, opts),
         :ok <- consume_nonce(fields.nonce),
         {:ok, recovered} <- recover_siwe_signer(message, signature) do
      if String.downcase(recovered) == String.downcase(address) do
        {:ok, %{verified: true, address: address, fields: fields}}
      else
        {:error, "Signature does not match address"}
      end
    end
  end

  @doc """
  Reconstructs the EIP-4361 personal_sign message and recovers the signer.

  The SIWE message is prefixed with `\\x19Ethereum Signed Message:\\n` followed
  by the byte length of the message, per the personal_sign convention.
  """
  def recover_siwe_signer(message, signature) do
    prefixed = "\u0019Ethereum Signed Message:\n#{byte_size(message)}#{message}"

    case ExKeccak.recover(signature, ExKeccak.hash_256(prefixed)) do
      {:ok, recovered} -> {:ok, String.downcase(recovered)}
      {:error, reason} -> {:error, "Signature recovery failed: #{inspect(reason)}"}
      _ -> {:error, "Unexpected signature recovery result"}
    end
  end

  # ---------------------------------------------------------------------------
  # EIP-1271 Contract Wallet Verification
  # ---------------------------------------------------------------------------

  @doc """
  Verifies a signature using EIP-1271 (Contract Wallet Signature Validation).

  Calls the `isValidSignature(hash, signature)` method on the contract at `contract_address`
  via an Ethereum JSON-RPC call and checks that the magic value `0x1626ba7e` is returned.

  ## Parameters

    * `message` — the original message (will be hashed with keccak256)
    * `signature` — the hex-encoded signature bytes
    * `contract_address` — the address of the contract wallet
    * `opts` — optional keyword list:
      - `:rpc_url` — the Ethereum RPC endpoint (default: read from config)

  Returns `{:ok, %{verified: true, address: contract_address}}`
  or `{:error, reason}`.
  """
  def verify_eip1271(message, signature, contract_address, opts \\ []) do
    rpc_url = opts[:rpc_url] || Application.get_env(:lux, :rpc_url, "http://localhost:8545")

    message_hash =
      message
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    # EIP-1271: isValidSignature(bytes32 _hash, bytes _signature) returns (bytes4)
    # Function selector: 0x1626ba7e
    # ABI-encode: selector + _hash (32 bytes, left-padded) + _signature (dynamic)
    selector = "1626ba7e"
    hash_padded = String.pad_leading(message_hash, 64, "0")

    sig_without_prefix =
      signature
      |> String.trim_leading("0x")
      |> String.trim_leading("0X")

    sig_length = byte_size(sig_without_prefix) |> Integer.to_string(16) |> String.pad_leading(64, "0")
    sig_padded = String.pad_trailing(sig_without_prefix, byte_size(sig_without_prefix) * 2, "0")

    data = "0x#{selector}#{hash_padded}#{sig_length}#{sig_padded}"

    # Build the JSON-RPC call payload
    call_data = %{
      jsonrpc: "2.0",
      method: "eth_call",
      params: [
        %{
          to: contract_address,
          data: data
        },
        "latest"
      ],
      id: 1
    }

    case post_json(rpc_url, call_data) do
      {:ok, %{"result" => "0x1626ba7e" <> _rest}} ->
        {:ok, %{verified: true, address: contract_address}}

      {:ok, %{"result" => result}} ->
        {:error, "EIP-1271 verification failed: unexpected magic value #{result}"}

      {:ok, %{"error" => error}} ->
        {:error, "EIP-1271 RPC error: #{inspect(error)}"}

      {:error, reason} ->
        {:error, "EIP-1271 RPC call failed: #{inspect(reason)}"}
    end
  end

  defp post_json(url, body) do
    # Use Req if available, otherwise fallback to a simple HTTPoison-like call
    case Application.get_env(:lux, :http_client, :req) do
      :req ->
        case Req.post(url, json: body, receive_timeout: 10_000) do
          {:ok, %{status: 200, body: resp_body}} when is_map(resp_body) ->
            {:ok, resp_body}

          {:ok, %{status: 200, body: resp_body}} when is_binary(resp_body) ->
            {:ok, Jason.decode!(resp_body)}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        {:error, "No HTTP client configured"}
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization
  # ---------------------------------------------------------------------------

  @doc """
  Authorizes a user action based on their roles and the roles required for the action.

  Unlike the simple role-overlap check, this version maps the `action` to the
  `required_roles` parameter so that different actions can have different
  permission requirements.

  ## Parameters

    * `action` — the action being authorized (e.g., `:read`, `:write`, `:admin`)
      Ignored if `required_roles` is a list — it provides context for logging.
      If `required_roles` is a keyword list mapping actions to role lists,
      the action is used to look up the specific required roles.

    * `user_roles` — list of roles the user has (e.g., `[:admin, :editor]`)
    * `required_roles` — either:
      - A flat list of roles (any one grants access)
      - A keyword list mapping actions to required role lists

  ## Examples

      # Flat list — any matching role grants access
      Lux.Web3.Auth.authorize(:read, [:editor], [:admin, :editor])
      # => {:ok, :authorized}

      # Action-specific — :write needs :editor or :admin
      Lux.Web3.Auth.authorize(:write, [:viewer], [write: [:editor, :admin], read: [:viewer, :editor, :admin]])
      # => {:error, :forbidden}

      # No matching action rule
      Lux.Web3.Auth.authorize(:delete, [:admin], [read: [:viewer]])
      # => {:error, :forbidden}
  """
  def authorize(action, user_roles, required_roles) do
    roles_for_action =
      if Keyword.keyword?(required_roles) do
        Keyword.get(required_roles, action, [])
      else
        required_roles
      end

    has_role = Enum.any?(roles_for_action, fn r -> r in user_roles end)

    if has_role do
      {:ok, :authorized}
    else
      {:error, :forbidden}
    end
  end
end

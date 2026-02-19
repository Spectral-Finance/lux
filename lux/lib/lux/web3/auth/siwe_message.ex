defmodule Lux.Web3.Auth.SIWEMessage do
  @moduledoc """
  Implements EIP-4361: Sign-In with Ethereum message parsing and creation.

  Provides functionality to create, parse, and validate SIWE messages following
  the EIP-4361 specification. These messages enable Ethereum-based authentication
  by having users sign a structured message with their wallet.

  ## Message Format

  The SIWE message format follows EIP-4361:

      {domain} wants you to sign in with your Ethereum account:
      {address}

      {statement}

      URI: {uri}
      Version: {version}
      Chain ID: {chain_id}
      Nonce: {nonce}
      Issued At: {issued_at}
      Expiration Time: {expiration_time}
      Not Before: {not_before}
      Request ID: {request_id}
      Resources:
      - {resource_1}
      - {resource_2}

  ## Examples

      iex> msg = SIWEMessage.new(%{
      ...>   domain: "example.com",
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
      ...>   statement: "Sign in to Example",
      ...>   uri: "https://example.com/login",
      ...>   version: "1",
      ...>   chain_id: 1,
      ...>   nonce: "abc123def456",
      ...>   issued_at: ~U[2024-01-01 00:00:00Z]
      ...> })
      iex> SIWEMessage.to_string(msg)
      "example.com wants you to sign in with your Ethereum account:\\n0x71C7656EC7ab88b098defB751B7401B5f6d8976F\\n\\nSign in to Example\\n\\nURI: https://example.com/login\\nVersion: 1\\nChain ID: 1\\nNonce: abc123def456\\nIssued At: 2024-01-01T00:00:00Z"
  """

  @type t :: %__MODULE__{
          domain: String.t(),
          address: String.t(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: pos_integer(),
          nonce: String.t(),
          issued_at: DateTime.t(),
          expiration_time: DateTime.t() | nil,
          not_before: DateTime.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  @enforce_keys [:domain, :address, :uri, :version, :chain_id, :nonce, :issued_at]
  defstruct [
    :domain,
    :address,
    :statement,
    :uri,
    :version,
    :chain_id,
    :nonce,
    :issued_at,
    :expiration_time,
    :not_before,
    :request_id,
    resources: []
  ]

  @nonce_length 16
  @eip55_address_regex ~r/^0x[0-9a-fA-F]{40}$/

  @doc """
  Creates a new SIWE message struct.

  ## Parameters

    * `attrs` - A map containing the message fields. Required fields:
      * `:domain` - The domain requesting the sign-in
      * `:address` - The Ethereum address (EIP-55 checksummed)
      * `:uri` - The URI of the resource
      * `:version` - The SIWE version (currently "1")
      * `:chain_id` - The EIP-155 chain ID
      * `:nonce` - A random nonce for replay protection
      * `:issued_at` - When the message was issued

  ## Returns

    * `{:ok, %SIWEMessage{}}` on success
    * `{:error, reason}` on validation failure
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_domain(attrs[:domain]),
         :ok <- validate_address(attrs[:address]),
         :ok <- validate_uri(attrs[:uri]),
         :ok <- validate_version(attrs[:version]),
         :ok <- validate_chain_id(attrs[:chain_id]),
         :ok <- validate_nonce(attrs[:nonce]),
         :ok <- validate_issued_at(attrs[:issued_at]) do
      {:ok,
       %__MODULE__{
         domain: attrs[:domain],
         address: attrs[:address],
         statement: attrs[:statement],
         uri: attrs[:uri],
         version: attrs[:version] || "1",
         chain_id: attrs[:chain_id],
         nonce: attrs[:nonce],
         issued_at: attrs[:issued_at],
         expiration_time: attrs[:expiration_time],
         not_before: attrs[:not_before],
         request_id: attrs[:request_id],
         resources: attrs[:resources] || []
       }}
    end
  end

  @doc """
  Generates a cryptographically secure random nonce.

  ## Returns

    A hex-encoded string of #{@nonce_length} random bytes (#{@nonce_length * 2} hex chars).
  """
  @spec generate_nonce() :: String.t()
  def generate_nonce do
    @nonce_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Converts a SIWE message struct to its string representation following EIP-4361 format.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = msg) do
    lines = [
      "#{msg.domain} wants you to sign in with your Ethereum account:",
      msg.address,
      "",
      msg.statement || "",
      "",
      "URI: #{msg.uri}",
      "Version: #{msg.version}",
      "Chain ID: #{msg.chain_id}",
      "Nonce: #{msg.nonce}",
      "Issued At: #{format_datetime(msg.issued_at)}"
    ]

    lines =
      lines
      |> maybe_append("Expiration Time: ", msg.expiration_time)
      |> maybe_append("Not Before: ", msg.not_before)
      |> maybe_append_raw("Request ID: #{msg.request_id}", msg.request_id)

    lines =
      if msg.resources != [] do
        lines ++ ["Resources:"] ++ Enum.map(msg.resources, &"- #{&1}")
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  @doc """
  Parses a SIWE message string back into a struct.

  ## Returns

    * `{:ok, %SIWEMessage{}}` on success
    * `{:error, reason}` on parse failure
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(message) when is_binary(message) do
    lines = String.split(message, "\n")

    with {:ok, domain} <- parse_domain(lines),
         {:ok, address} <- parse_address(lines),
         {:ok, fields} <- parse_fields(lines) do
      new(%{
        domain: domain,
        address: address,
        statement: fields[:statement],
        uri: fields[:uri],
        version: fields[:version],
        chain_id: fields[:chain_id],
        nonce: fields[:nonce],
        issued_at: fields[:issued_at],
        expiration_time: fields[:expiration_time],
        not_before: fields[:not_before],
        request_id: fields[:request_id],
        resources: fields[:resources] || []
      })
    end
  end

  @doc """
  Validates a SIWE message, checking expiration and not-before times.

  ## Options

    * `:now` - The current time (defaults to `DateTime.utc_now/0`)

  ## Returns

    * `:ok` if the message is valid
    * `{:error, reason}` if validation fails
  """
  @spec validate(t(), keyword()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = msg, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with :ok <- check_expiration(msg.expiration_time, now),
         :ok <- check_not_before(msg.not_before, now) do
      :ok
    end
  end

  # Private helpers

  defp validate_domain(nil), do: {:error, "domain is required"}
  defp validate_domain(""), do: {:error, "domain cannot be empty"}
  defp validate_domain(d) when is_binary(d), do: :ok
  defp validate_domain(_), do: {:error, "domain must be a string"}

  defp validate_address(nil), do: {:error, "address is required"}

  defp validate_address(addr) when is_binary(addr) do
    if Regex.match?(@eip55_address_regex, addr) do
      :ok
    else
      {:error, "invalid Ethereum address format"}
    end
  end

  defp validate_address(_), do: {:error, "address must be a string"}

  defp validate_uri(nil), do: {:error, "uri is required"}
  defp validate_uri(""), do: {:error, "uri cannot be empty"}
  defp validate_uri(u) when is_binary(u), do: :ok
  defp validate_uri(_), do: {:error, "uri must be a string"}

  defp validate_version(nil), do: :ok
  defp validate_version("1"), do: :ok
  defp validate_version(_), do: {:error, "version must be \"1\""}

  defp validate_chain_id(nil), do: {:error, "chain_id is required"}
  defp validate_chain_id(id) when is_integer(id) and id > 0, do: :ok
  defp validate_chain_id(_), do: {:error, "chain_id must be a positive integer"}

  defp validate_nonce(nil), do: {:error, "nonce is required"}
  defp validate_nonce(""), do: {:error, "nonce cannot be empty"}
  defp validate_nonce(n) when is_binary(n) and byte_size(n) >= 8, do: :ok
  defp validate_nonce(n) when is_binary(n), do: {:error, "nonce must be at least 8 characters"}
  defp validate_nonce(_), do: {:error, "nonce must be a string"}

  defp validate_issued_at(nil), do: {:error, "issued_at is required"}
  defp validate_issued_at(%DateTime{}), do: :ok
  defp validate_issued_at(_), do: {:error, "issued_at must be a DateTime"}

  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(nil), do: nil

  defp maybe_append(lines, _prefix, nil), do: lines

  defp maybe_append(lines, prefix, %DateTime{} = dt),
    do: lines ++ ["#{prefix}#{format_datetime(dt)}"]

  defp maybe_append_raw(lines, _text, nil), do: lines
  defp maybe_append_raw(lines, text, _val), do: lines ++ [text]

  defp check_expiration(nil, _now), do: :ok

  defp check_expiration(%DateTime{} = exp, now) do
    case DateTime.compare(now, exp) do
      :lt -> :ok
      _ -> {:error, "message has expired"}
    end
  end

  defp check_not_before(nil, _now), do: :ok

  defp check_not_before(%DateTime{} = nb, now) do
    case DateTime.compare(now, nb) do
      :lt -> {:error, "message is not yet valid"}
      _ -> :ok
    end
  end

  defp parse_domain([first_line | _]) do
    case String.split(first_line, " wants you to sign in with your Ethereum account:") do
      [domain, ""] -> {:ok, domain}
      _ -> {:error, "invalid SIWE message format: missing domain header"}
    end
  end

  defp parse_domain(_), do: {:error, "empty message"}

  defp parse_address([_, address_line | _]) do
    address = String.trim(address_line)

    if Regex.match?(@eip55_address_regex, address) do
      {:ok, address}
    else
      {:error, "invalid address in SIWE message"}
    end
  end

  defp parse_address(_), do: {:error, "missing address in SIWE message"}

  defp parse_fields(lines) do
    field_map =
      lines
      |> Enum.reduce(%{resources: [], in_resources: false, statement_lines: []}, fn line, acc ->
        cond do
          acc.in_resources && String.starts_with?(line, "- ") ->
            resource = String.trim_leading(line, "- ")
            %{acc | resources: acc.resources ++ [resource]}

          String.starts_with?(line, "Resources:") ->
            %{acc | in_resources: true}

          String.starts_with?(line, "URI: ") ->
            Map.put(acc, :uri, String.trim_leading(line, "URI: "))

          String.starts_with?(line, "Version: ") ->
            Map.put(acc, :version, String.trim_leading(line, "Version: "))

          String.starts_with?(line, "Chain ID: ") ->
            chain_id = line |> String.trim_leading("Chain ID: ") |> String.to_integer()
            Map.put(acc, :chain_id, chain_id)

          String.starts_with?(line, "Nonce: ") ->
            Map.put(acc, :nonce, String.trim_leading(line, "Nonce: "))

          String.starts_with?(line, "Issued At: ") ->
            {:ok, dt, _} = line |> String.trim_leading("Issued At: ") |> DateTime.from_iso8601()
            Map.put(acc, :issued_at, dt)

          String.starts_with?(line, "Expiration Time: ") ->
            {:ok, dt, _} =
              line |> String.trim_leading("Expiration Time: ") |> DateTime.from_iso8601()

            Map.put(acc, :expiration_time, dt)

          String.starts_with?(line, "Not Before: ") ->
            {:ok, dt, _} =
              line |> String.trim_leading("Not Before: ") |> DateTime.from_iso8601()

            Map.put(acc, :not_before, dt)

          String.starts_with?(line, "Request ID: ") ->
            Map.put(acc, :request_id, String.trim_leading(line, "Request ID: "))

          true ->
            acc
        end
      end)

    {:ok, field_map}
  end
end

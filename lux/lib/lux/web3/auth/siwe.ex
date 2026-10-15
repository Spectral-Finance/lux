defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  EIP-4361 Sign-In with Ethereum (SIWE) message builder, formatter, parser,
  and temporal/domain validator.
  """

  @type t :: %__MODULE__{
          domain: String.t(),
          address: String.t(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: pos_integer(),
          nonce: String.t(),
          issued_at: String.t(),
          expiration_time: String.t() | nil,
          not_before: String.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  defstruct domain: "lux.spectral.finance",
            address: nil,
            statement: "Sign in with Ethereum to the Lux Agent Framework.",
            uri: "https://lux.spectral.finance/auth",
            version: "1",
            chain_id: 1,
            nonce: nil,
            issued_at: nil,
            expiration_time: nil,
            not_before: nil,
            request_id: nil,
            resources: []

  @doc """
  Generates a cryptographically random alphanumeric EIP-4361 nonce (minimum 8 chars).
  """
  @spec generate_nonce(pos_integer()) :: String.t()
  def generate_nonce(byte_len \\ 12) do
    byte_len
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Builds a `%SIWE{}` struct with defaults for `nonce` and `issued_at`.
  """
  @spec build(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def build(attrs) when is_map(attrs) or is_list(attrs) do
    params = Map.new(attrs)
    address = Map.get(params, :address)

    if is_binary(address) and String.starts_with?(address, "0x") and byte_size(address) == 42 do
      now_iso = DateTime.to_iso8601(DateTime.utc_now())

      msg =
        __MODULE__
        |> struct(params)
        |> Map.put_new(:nonce, generate_nonce())
        |> Map.update(:nonce, generate_nonce(), fn v -> v || generate_nonce() end)
        |> Map.update(:issued_at, now_iso, fn v -> v || now_iso end)

      {:ok, msg}
    else
      {:error, :invalid_address}
    end
  end

  @doc """
  Formats a `%SIWE{}` struct into its canonical EIP-4361 plaintext string representation.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = msg) do
    header = "#{msg.domain} wants you to sign in with your Ethereum account:\n#{msg.address}\n"

    statement_block =
      if is_binary(msg.statement) and msg.statement != "" do
        "\n#{msg.statement}\n"
      else
        "\n"
      end

    fields =
      [
        "URI: #{msg.uri}",
        "Version: #{msg.version}",
        "Chain ID: #{msg.chain_id}",
        "Nonce: #{msg.nonce}",
        "Issued At: #{msg.issued_at}"
      ]
      |> maybe_append("Expiration Time", msg.expiration_time)
      |> maybe_append("Not Before", msg.not_before)
      |> maybe_append("Request ID", msg.request_id)
      |> maybe_append_resources(msg.resources)

    header <> statement_block <> "\n" <> Enum.join(fields, "\n")
  end

  @doc """
  Parses an EIP-4361 formatted plaintext message back into a `%SIWE{}` struct.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, :invalid_siwe_message}
  def parse(text) when is_binary(text) do
    lines = String.split(text, "\n")

    with [domain_line, address | rest] <- lines,
         [domain, "wants you to sign in with your Ethereum account:"] <-
           String.split(domain_line, " ", parts: 2),
         true <- String.starts_with?(address, "0x") and byte_size(address) == 42 do
      {statement, kv_lines} = extract_statement_and_fields(rest)
      kv_map = parse_kv_lines(kv_lines)
      resources = extract_resources(kv_lines)

      chain_id =
        case Integer.parse(Map.get(kv_map, "Chain ID", "1")) do
          {n, ""} when n > 0 -> n
          _ -> 1
        end

      {:ok,
       %__MODULE__{
         domain: domain,
         address: address,
         statement: statement,
         uri: Map.get(kv_map, "URI", ""),
         version: Map.get(kv_map, "Version", "1"),
         chain_id: chain_id,
         nonce: Map.get(kv_map, "Nonce"),
         issued_at: Map.get(kv_map, "Issued At"),
         expiration_time: Map.get(kv_map, "Expiration Time"),
         not_before: Map.get(kv_map, "Not Before"),
         request_id: Map.get(kv_map, "Request ID"),
         resources: resources
       }}
    else
      _ -> {:error, :invalid_siwe_message}
    end
  end

  @doc """
  Validates domain, nonce, version, `expiration_time`, and `not_before` constraints
  on a `%SIWE{}` message.
  """
  @spec validate(t(), keyword()) :: :ok | {:error, atom()}
  def validate(%__MODULE__{} = msg, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    expected_domain = Keyword.get(opts, :domain)
    expected_nonce = Keyword.get(opts, :nonce)

    cond do
      msg.version != "1" ->
        {:error, :unsupported_version}

      is_nil(msg.nonce) or byte_size(msg.nonce) < 8 ->
        {:error, :invalid_nonce}

      not is_nil(expected_domain) and msg.domain != expected_domain ->
        {:error, :domain_mismatch}

      not is_nil(expected_nonce) and msg.nonce != expected_nonce ->
        {:error, :nonce_mismatch}

      expired?(msg.expiration_time, now) ->
        {:error, :message_expired}

      not_yet_valid?(msg.not_before, now) ->
        {:error, :message_not_yet_valid}

      true ->
        :ok
    end
  end

  defp expired?(nil, _now), do: false

  defp expired?(iso_str, now) when is_binary(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, exp_dt, _offset} -> DateTime.compare(now, exp_dt) == :gt
      _ -> true
    end
  end

  defp not_yet_valid?(nil, _now), do: false

  defp not_yet_valid?(iso_str, now) when is_binary(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, nbf_dt, _offset} -> DateTime.compare(now, nbf_dt) == :lt
      _ -> true
    end
  end

  defp maybe_append(list, _label, nil), do: list
  defp maybe_append(list, label, value), do: list ++ ["#{label}: #{value}"]

  defp maybe_append_resources(list, []), do: list

  defp maybe_append_resources(list, resources) when is_list(resources) do
    items = Enum.map(resources, &"- #{&1}")
    list ++ ["Resources:" | items]
  end

  defp extract_statement_and_fields(["" | rest]) do
    case rest do
      ["" | kv_lines] -> {nil, kv_lines}
      [stmt, "" | kv_lines] -> {stmt, kv_lines}
      other -> {nil, other}
    end
  end

  defp extract_statement_and_fields(other), do: {nil, other}

  defp parse_kv_lines(lines) do
    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        [key, val] -> Map.put(acc, key, val)
        _ -> acc
      end
    end)
  end

  defp extract_resources(lines) do
    lines
    |> Enum.drop_while(&(&1 != "Resources:"))
    |> Enum.drop(1)
    |> Enum.take_while(&String.starts_with?(&1, "- "))
    |> Enum.map(&String.trim_leading(&1, "- "))
  end
end

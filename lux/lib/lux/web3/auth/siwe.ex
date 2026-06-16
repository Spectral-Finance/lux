defmodule Lux.Web3.Auth.Siwe do
  @moduledoc """
  Parser and validator for EIP-4361 Sign-In with Ethereum messages.

  The parser keeps the original SIWE message intact for signature verification
  while exposing normalized fields that can be used by Lux sessions and access
  policies.
  """

  @required_fields [:domain, :address, :uri, :version, :chain_id, :nonce, :issued_at]
  @address_regex ~r/^0x[0-9a-fA-F]{40}$/

  @type t :: %{
          raw: String.t(),
          domain: String.t(),
          address: String.t(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: non_neg_integer(),
          nonce: String.t(),
          issued_at: DateTime.t(),
          expiration_time: DateTime.t() | nil,
          not_before: DateTime.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(message) when is_binary(message) do
    lines = String.split(message, "\n", trim: false)

    with {:ok, domain} <- parse_domain(Enum.at(lines, 0)),
         {:ok, address} <- parse_address(Enum.at(lines, 2)),
         {:ok, fields, statement, resources} <- parse_body(Enum.drop(lines, 3)),
         {:ok, chain_id} <- parse_integer(fields["Chain ID"], "Chain ID"),
         {:ok, issued_at} <- parse_datetime(fields["Issued At"], "Issued At"),
         {:ok, expiration_time} <- parse_optional_datetime(fields["Expiration Time"], "Expiration Time"),
         {:ok, not_before} <- parse_optional_datetime(fields["Not Before"], "Not Before"),
         parsed <- %{
           raw: message,
           domain: domain,
           address: normalize_address(address),
           statement: blank_to_nil(statement),
           uri: fields["URI"],
           version: fields["Version"],
           chain_id: chain_id,
           nonce: fields["Nonce"],
           issued_at: issued_at,
           expiration_time: expiration_time,
           not_before: not_before,
           request_id: fields["Request ID"],
           resources: resources
         },
         :ok <- require_fields(parsed) do
      {:ok, parsed}
    end
  end

  def parse(_), do: {:error, "SIWE message must be a string"}

  @spec validate(String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def validate(message, opts \\ []) do
    with {:ok, parsed} <- parse(message),
         :ok <- validate_domain(parsed, Keyword.get(opts, :domain)),
         :ok <- validate_uri(parsed, Keyword.get(opts, :uri)),
         :ok <- validate_chain(parsed, Keyword.get(opts, :chain_ids)),
         :ok <- validate_nonce(parsed, Keyword.get(opts, :nonce)),
         :ok <- validate_time_window(parsed, Keyword.get(opts, :now, DateTime.utc_now())) do
      {:ok, parsed}
    end
  end

  @spec normalize_address(String.t()) :: String.t()
  def normalize_address(address) when is_binary(address), do: String.downcase(address)

  @spec address?(String.t()) :: boolean()
  def address?(address) when is_binary(address), do: Regex.match?(@address_regex, address)
  def address?(_), do: false

  defp parse_domain(nil), do: {:error, "Missing SIWE domain line"}

  defp parse_domain(line) do
    suffix = " wants you to sign in with your Ethereum account:"

    if String.ends_with?(line, suffix) do
      domain = String.replace_suffix(line, suffix, "")

      if domain == "" do
        {:error, "SIWE domain cannot be empty"}
      else
        {:ok, domain}
      end
    else
      {:error, "Invalid SIWE domain line"}
    end
  end

  defp parse_address(address) when is_binary(address) do
    if address?(address), do: {:ok, address}, else: {:error, "Invalid SIWE address"}
  end

  defp parse_address(_), do: {:error, "Missing SIWE address"}

  defp parse_body(lines) do
    {fields, statement_lines, resources, _mode} =
      Enum.reduce(lines, {%{}, [], [], :statement}, fn line, {fields, statement, resources, mode} ->
        cond do
          line == "Resources:" ->
            {fields, statement, resources, :resources}

          mode == :resources and String.starts_with?(line, "- ") ->
            {fields, statement, [String.trim_leading(line, "- ") | resources], mode}

          mode == :resources and String.trim(line) == "" ->
            {fields, statement, resources, mode}

          mode == :resources ->
            {fields, statement, resources, mode}

          String.contains?(line, ":") and field_key?(line) ->
            [key, value] = String.split(line, ":", parts: 2)
            {Map.put(fields, key, String.trim_leading(value)), statement, resources, :fields}

          String.trim(line) == "" ->
            {fields, statement, resources, mode}

          mode == :statement ->
            {fields, statement ++ [line], resources, mode}

          true ->
            {fields, statement, resources, mode}
        end
      end)

    {:ok, fields, statement_lines |> Enum.join("\n") |> String.trim(), Enum.reverse(resources)}
  end

  defp field_key?(line) do
    key = line |> String.split(":", parts: 2) |> hd()
    key in ["URI", "Version", "Chain ID", "Nonce", "Issued At", "Expiration Time", "Not Before", "Request ID"]
  end

  defp parse_integer(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "#{field} must be an integer"}
    end
  end

  defp parse_integer(_, field), do: {:error, "Missing #{field}"}

  defp parse_datetime(value, field) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, "#{field} must be an ISO-8601 timestamp"}
    end
  end

  defp parse_datetime(_, field), do: {:error, "Missing #{field}"}

  defp parse_optional_datetime(nil, _field), do: {:ok, nil}
  defp parse_optional_datetime("", _field), do: {:ok, nil}
  defp parse_optional_datetime(value, field), do: parse_datetime(value, field)

  defp require_fields(parsed) do
    missing =
      @required_fields
      |> Enum.filter(fn field ->
        value = Map.fetch!(parsed, field)
        is_nil(value) or value == ""
      end)

    case missing do
      [] -> :ok
      [field | _] -> {:error, "Missing SIWE field #{field}"}
    end
  end

  defp validate_domain(_parsed, nil), do: :ok

  defp validate_domain(parsed, expected) do
    if parsed.domain == expected, do: :ok, else: {:error, "SIWE domain mismatch"}
  end

  defp validate_uri(_parsed, nil), do: :ok

  defp validate_uri(parsed, expected) do
    if parsed.uri == expected, do: :ok, else: {:error, "SIWE URI mismatch"}
  end

  defp validate_chain(_parsed, nil), do: :ok

  defp validate_chain(parsed, chain_ids) when is_list(chain_ids) do
    if parsed.chain_id in chain_ids, do: :ok, else: {:error, "SIWE chain ID is not allowed"}
  end

  defp validate_chain(parsed, chain_id) when is_integer(chain_id), do: validate_chain(parsed, [chain_id])

  defp validate_nonce(_parsed, nil), do: :ok

  defp validate_nonce(parsed, expected) do
    if parsed.nonce == expected, do: :ok, else: {:error, "SIWE nonce mismatch"}
  end

  defp validate_time_window(parsed, now) do
    cond do
      parsed.not_before && DateTime.compare(now, parsed.not_before) == :lt ->
        {:error, "SIWE message is not valid yet"}

      parsed.expiration_time && DateTime.compare(now, parsed.expiration_time) != :lt ->
        {:error, "SIWE message has expired"}

      true ->
        :ok
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end

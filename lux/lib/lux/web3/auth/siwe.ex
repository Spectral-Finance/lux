defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  EIP-4361 Sign-In with Ethereum message helpers.
  """

  @nonce_pattern ~r/^[A-Za-z0-9]{8,}$/

  @doc """
  Builds an EIP-4361 message.
  """
  @spec build_message(map()) :: String.t()
  def build_message(attrs) do
    domain = required!(attrs, :domain)
    address = required!(attrs, :address)
    statement = Map.get(attrs, :statement)
    resources = Map.get(attrs, :resources, [])

    [
      "#{domain} wants you to sign in with your Ethereum account:",
      address,
      nil,
      statement,
      nil,
      "URI: #{required!(attrs, :uri)}",
      "Version: #{Map.get(attrs, :version, 1)}",
      "Chain ID: #{required!(attrs, :chain_id)}",
      "Nonce: #{required!(attrs, :nonce)}",
      "Issued At: #{required!(attrs, :issued_at)}",
      optional_line("Expiration Time", Map.get(attrs, :expiration_time)),
      optional_line("Not Before", Map.get(attrs, :not_before)),
      optional_line("Request ID", Map.get(attrs, :request_id)),
      resources_block(resources)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  @doc """
  Parses the fields Lux needs from an EIP-4361 message.
  """
  @spec parse_message(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_message(message) when is_binary(message) do
    lines = String.split(message, "\n", trim: false)

    with [domain_line, address | _rest] <- lines,
         [domain] <- Regex.run(~r/^(.+) wants you to sign in with your Ethereum account:$/, domain_line, capture: :all_but_first),
         {:ok, fields} <- parse_fields(lines) do
      {:ok,
       fields
       |> Map.put(:domain, domain)
       |> Map.put(:address, address)
       |> Map.put(:resources, parse_resources(lines))}
    else
      _ -> {:error, :invalid_siwe_message}
    end
  end

  @doc """
  Validates message fields and optional expected constraints.
  """
  @spec validate_message(map(), keyword() | map()) :: :ok | {:error, term()}
  def validate_message(message, opts \\ %{}) do
    cond do
      not valid_address?(Map.get(message, :address)) ->
        {:error, :invalid_address}

      not Regex.match?(@nonce_pattern, to_string(Map.get(message, :nonce))) ->
        {:error, :invalid_nonce}

      option(opts, :domain, Map.get(message, :domain)) != Map.get(message, :domain) ->
        {:error, :domain_mismatch}

      option(opts, :chain_id, Map.get(message, :chain_id)) != Map.get(message, :chain_id) ->
        {:error, :chain_id_mismatch}

      expired?(Map.get(message, :expiration_time), option(opts, :now, DateTime.utc_now())) ->
        {:error, :expired}

      not_before?(Map.get(message, :not_before), option(opts, :now, DateTime.utc_now())) ->
        {:error, :not_before}

      true ->
        :ok
    end
  end

  @doc """
  Verifies a SIWE signature through an injected verifier.

  The verifier function receives `{message, signature, opts}` and should return
  `{:ok, recovered_address}` or `{:error, reason}`. Keeping verification
  injectable lets applications choose the signing stack they already trust.
  """
  @spec verify_signature(String.t(), String.t(), keyword() | map()) :: {:ok, String.t()} | {:error, term()}
  def verify_signature(message, signature, opts \\ %{}) do
    case option(opts, :verifier, nil) do
      nil -> {:error, :signature_verifier_not_configured}
      verifier when is_function(verifier, 3) -> verifier.(message, signature, opts)
    end
  end

  defp parse_fields(lines) do
    fields =
      lines
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ": ", parts: 2) do
          ["URI", value] -> Map.put(acc, :uri, value)
          ["Version", value] -> Map.put(acc, :version, String.to_integer(value))
          ["Chain ID", value] -> Map.put(acc, :chain_id, String.to_integer(value))
          ["Nonce", value] -> Map.put(acc, :nonce, value)
          ["Issued At", value] -> Map.put(acc, :issued_at, value)
          ["Expiration Time", value] -> Map.put(acc, :expiration_time, value)
          ["Not Before", value] -> Map.put(acc, :not_before, value)
          ["Request ID", value] -> Map.put(acc, :request_id, value)
          _ -> acc
        end
      end)

    required = [:uri, :version, :chain_id, :nonce, :issued_at]

    if Enum.all?(required, &Map.has_key?(fields, &1)), do: {:ok, fields}, else: {:error, :missing_fields}
  rescue
    ArgumentError -> {:error, :invalid_numeric_field}
  end

  defp parse_resources(lines) do
    lines
    |> Enum.drop_while(&(&1 != "Resources:"))
    |> Enum.drop(1)
    |> Enum.take_while(&String.starts_with?(&1, "- "))
    |> Enum.map(&String.replace_prefix(&1, "- ", ""))
  end

  defp resources_block([]), do: nil

  defp resources_block(resources) do
    "Resources:\n" <> Enum.map_join(resources, "\n", &"- #{&1}")
  end

  defp optional_line(_label, nil), do: nil
  defp optional_line(label, value), do: "#{label}: #{value}"

  defp expired?(nil, _now), do: false

  defp expired?(timestamp, now) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, expires_at, _offset} -> DateTime.compare(expires_at, now) != :gt
      _ -> true
    end
  end

  defp not_before?(nil, _now), do: false

  defp not_before?(timestamp, now) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, not_before, _offset} -> DateTime.compare(not_before, now) == :gt
      _ -> true
    end
  end

  defp valid_address?("0x" <> rest), do: Regex.match?(~r/^[0-9a-fA-F]{40}$/, rest)
  defp valid_address?(_address), do: false

  defp required!(attrs, key), do: Map.get(attrs, key) || raise ArgumentError, "#{key} is required"

  defp option(opts, key, default) do
    case opts[key] do
      nil -> default
      value -> value
    end
  end
end

defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  Sign-In with Ethereum (EIP-4361) message parsing, validation, and authentication.
  """

  alias Lux.Web3.Auth.Signature

  @nonce_pattern ~r/^[A-Za-z0-9]{8,}$/

  @type message :: %{
          required(:domain) => String.t(),
          required(:address) => String.t(),
          required(:uri) => String.t(),
          required(:version) => String.t(),
          required(:chain_id) => non_neg_integer(),
          required(:nonce) => String.t(),
          required(:issued_at) => String.t(),
          optional(:statement) => String.t(),
          optional(:expiration_time) => String.t(),
          optional(:not_before) => String.t(),
          optional(:request_id) => String.t(),
          optional(:resources) => [String.t()]
        }

  @doc """
  Builds an EIP-4361 message string.
  """
  @spec build_message(keyword() | map()) :: String.t()
  def build_message(attrs) do
    resources = get(attrs, :resources, [])

    [
      "#{required!(attrs, :domain)} wants you to sign in with your Ethereum account:",
      required!(attrs, :address),
      "",
      get(attrs, :statement),
      blank_after_statement(get(attrs, :statement)),
      "URI: #{required!(attrs, :uri)}",
      "Version: #{get(attrs, :version, "1")}",
      "Chain ID: #{required!(attrs, :chain_id)}",
      "Nonce: #{required!(attrs, :nonce)}",
      "Issued At: #{required!(attrs, :issued_at)}",
      optional_line("Expiration Time", get(attrs, :expiration_time)),
      optional_line("Not Before", get(attrs, :not_before)),
      optional_line("Request ID", get(attrs, :request_id)),
      resources_block(resources)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  @doc """
  Parses an EIP-4361 message into normalized fields.
  """
  @spec parse_message(String.t()) :: {:ok, message()} | {:error, term()}
  def parse_message(message) when is_binary(message) do
    lines = String.split(message, "\n", trim: false)

    with {:ok, domain} <- parse_domain(Enum.at(lines, 0)),
         address when is_binary(address) <- Enum.at(lines, 1),
         {:ok, fields} <- parse_fields(lines),
         {:ok, chain_id} <- parse_integer(fields["Chain ID"]) do
      {:ok,
       %{
         domain: domain,
         address: String.trim(address),
         statement: parse_statement(lines),
         uri: fields["URI"],
         version: fields["Version"],
         chain_id: chain_id,
         nonce: fields["Nonce"],
         issued_at: fields["Issued At"],
         expiration_time: fields["Expiration Time"],
         not_before: fields["Not Before"],
         request_id: fields["Request ID"],
         resources: parse_resources(lines)
       }
       |> drop_nil()}
    else
      _ -> {:error, :invalid_siwe_message}
    end
  end

  @doc """
  Validates EIP-4361 fields and optional caller constraints.
  """
  @spec validate_message(message(), keyword() | map()) :: :ok | {:error, term()}
  def validate_message(message, opts \\ %{}) do
    now = get(opts, :now, DateTime.utc_now())

    cond do
      not Signature.valid_address?(message[:address]) ->
        {:error, :invalid_address}

      to_string(message[:version]) != "1" ->
        {:error, :unsupported_version}

      not Regex.match?(@nonce_pattern, to_string(message[:nonce])) ->
        {:error, :invalid_nonce}

      expected_mismatch?(opts, :domain, message[:domain]) ->
        {:error, :domain_mismatch}

      expected_mismatch?(opts, :chain_id, message[:chain_id]) ->
        {:error, :chain_id_mismatch}

      expected_mismatch?(opts, :nonce, message[:nonce]) ->
        {:error, :nonce_mismatch}

      invalid_time?(message[:issued_at]) ->
        {:error, :invalid_issued_at}

      expired?(message[:expiration_time], now) ->
        {:error, :expired}

      not_before?(message[:not_before], now) ->
        {:error, :not_before}

      true ->
        :ok
    end
  end

  @doc """
  Parses, validates, and verifies a SIWE message signature.
  """
  @spec authenticate(String.t(), Signature.signature(), keyword() | map()) ::
          {:ok, message()} | {:error, term()}
  def authenticate(raw_message, signature, opts \\ %{}) do
    with {:ok, message} <- parse_message(raw_message),
         :ok <- validate_message(message, opts),
         :ok <- Signature.verify_personal_signature(raw_message, signature, message.address) do
      {:ok, message}
    end
  end

  defp parse_domain(line) do
    case Regex.run(~r/^(.+) wants you to sign in with your Ethereum account:$/, to_string(line)) do
      [_, domain] -> {:ok, domain}
      _ -> {:error, :invalid_domain_line}
    end
  end

  defp parse_fields(lines) do
    fields =
      Enum.reduce(lines, %{}, fn line, acc ->
        case String.split(line, ": ", parts: 2) do
          [label, value] when label in ["URI", "Version", "Chain ID", "Nonce", "Issued At"] ->
            Map.put(acc, label, value)

          [label, value] when label in ["Expiration Time", "Not Before", "Request ID"] ->
            Map.put(acc, label, value)

          _ ->
            acc
        end
      end)

    required = ["URI", "Version", "Chain ID", "Nonce", "Issued At"]

    if Enum.all?(required, &Map.has_key?(fields, &1)) do
      {:ok, fields}
    else
      {:error, :missing_required_fields}
    end
  end

  defp parse_statement(lines) do
    case Enum.drop(lines, 3) do
      [first | rest] when first != "" ->
        if String.starts_with?(first, "URI: ") do
          nil
        else
          [first | rest]
          |> Enum.take_while(&(&1 != ""))
          |> Enum.join("\n")
        end

      _ ->
        nil
    end
  end

  defp parse_resources(lines) do
    lines
    |> Enum.drop_while(&(&1 != "Resources:"))
    |> Enum.drop(1)
    |> Enum.take_while(&String.starts_with?(&1, "- "))
    |> Enum.map(&String.replace_prefix(&1, "- ", ""))
  end

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, :invalid_integer}
    end
  end

  defp optional_line(_label, nil), do: nil
  defp optional_line(label, value), do: "#{label}: #{value}"

  defp resources_block([]), do: nil
  defp resources_block(nil), do: nil

  defp resources_block(resources),
    do: "Resources:\n" <> Enum.map_join(resources, "\n", &"- #{&1}")

  defp blank_after_statement(nil), do: nil
  defp blank_after_statement(""), do: nil
  defp blank_after_statement(_statement), do: ""

  defp expired?(nil, _now), do: false
  defp expired?(timestamp, now), do: compare_time(timestamp, now, &(&1 != :gt))

  defp not_before?(nil, _now), do: false
  defp not_before?(timestamp, now), do: compare_time(timestamp, now, &(&1 == :gt))

  defp compare_time(timestamp, now, predicate) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, parsed, _offset} -> predicate.(DateTime.compare(parsed, now))
      _ -> true
    end
  end

  defp invalid_time?(nil), do: true

  defp invalid_time?(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, _parsed, _offset} -> false
      _ -> true
    end
  end

  defp expected_mismatch?(opts, key, actual) do
    case get(opts, key) do
      nil -> false
      expected -> expected != actual
    end
  end

  defp required!(attrs, key) do
    get(attrs, key) || raise ArgumentError, "#{key} is required"
  end

  defp get(data, key, default \\ nil)

  defp get(data, key, default) when is_map(data),
    do: Map.get(data, key) || Map.get(data, to_string(key), default)

  defp get(data, key, default) when is_list(data), do: Keyword.get(data, key, default)
  defp get(_data, _key, default), do: default

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end

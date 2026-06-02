defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  Sign-In with Ethereum (EIP-4361) implementation.

  Implements the EIP-4361 standard for authenticating Ethereum accounts
  through message signing. Provides message construction, parsing, and
  validation capabilities.
  """

  require Logger

  @typedoc "SIWE message fields"
  @type t :: %__MODULE__{
          domain: String.t(),
          address: String.t(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: non_neg_integer(),
          nonce: String.t(),
          issued_at: String.t(),
          expiration_time: String.t() | nil,
          not_before: String.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

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

  @default_version "1"
  @siwe_header "x-siwe-message"

  @doc """
  Builds an EIP-4361 compliant SIWE message string from the given fields.
  """
  @spec build_message(t()) :: String.t()
  def build_message(%__MODULE__{} = siwe) do
    lines =
      [
        "#{siwe.domain} wants you to sign in with your Ethereum account:",
        siwe.address
      ] ++
        optional_line(siwe.statement, "\n#{siwe.statement}") ++
        [
          "",
          "URI: #{siwe.uri}",
          "Version: #{siwe.version}",
          "Chain ID: #{siwe.chain_id}",
          "Nonce: #{siwe.nonce}",
          "Issued At: #{siwe.issued_at}"
        ] ++
        optional_line(siwe.expiration_time, "Expiration Time: #{siwe.expiration_time}") ++
        optional_line(siwe.not_before, "Not Before: #{siwe.not_before}") ++
        optional_line(siwe.request_id, "Request ID: #{siwe.request_id}") ++
        optional_resources(siwe.resources)

    Enum.join(lines, "\n")
  end

  @doc """
  Parses a SIWE message string into a struct.
  """
  @spec parse_message(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse_message(message) when is_binary(message) do
    lines = String.split(message, "\n")

    with {:ok, domain_line, rest1} <- extract_prefix(lines),
         {:ok, _address, rest2} <- extract_address(rest1),
         {:ok, statement, rest3} <- extract_statement(rest2),
         {:ok, uri, rest4} <- extract_field(rest3, "URI"),
         {:ok, version, rest5} <- extract_field(rest4, "Version"),
         {:ok, chain_id_str, rest6} <- extract_field(rest5, "Chain ID"),
         {:ok, nonce, rest7} <- extract_field(rest6, "Nonce"),
         {:ok, issued_at, rest8} <- extract_field(rest7, "Issued At"),
         {:ok, expiration, rest9} <- extract_optional_field(rest8, "Expiration Time"),
         {:ok, not_before, rest10} <- extract_optional_field(rest9, "Not Before"),
         {:ok, request_id, rest11} <- extract_optional_field(rest10, "Request ID"),
         resources <- extract_resources(rest11),
         {:ok, chain_id} <- parse_integer(chain_id_str) do
      siwe = %__MODULE__{
        domain: domain_line |> String.split(" wants you") |> List.first() |> String.trim(),
        address: Enum.at(String.split(domain_line, ": "), 1),
        statement: statement,
        uri: uri,
        version: version,
        chain_id: chain_id,
        nonce: nonce,
        issued_at: issued_at,
        expiration_time: expiration,
        not_before: not_before,
        request_id: request_id,
        resources: resources
      }

      {:ok, siwe}
    else
      {:error, reason} -> {:error, "Failed to parse SIWE message: #{reason}"}
    end
  end

  @doc """
  Generates a cryptographically secure random nonce.
  """
  @spec generate_nonce(non_neg_integer()) :: String.t()
  def generate_nonce(byte_length \\ 32) do
    byte_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Validates a SIWE message for correctness.
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = siwe) do
    cond do
      is_nil(siwe.domain) or siwe.domain == "" ->
        {:error, "Domain is required"}

      is_nil(siwe.address) or siwe.address == "" ->
        {:error, "Address is required"}

      is_nil(siwe.uri) or siwe.uri == "" ->
        {:error, "URI is required"}

      is_nil(siwe.nonce) or siwe.nonce == "" ->
        {:error, "Nonce is required"}

      is_nil(siwe.issued_at) or siwe.issued_at == "" ->
        {:error, "Issued At is required"}

      not is_valid_iso8601?(siwe.issued_at) ->
        {:error, "Issued At is not valid ISO-8601"}

      siwe.expiration_time != nil and not is_valid_iso8601?(siwe.expiration_time) ->
        {:error, "Expiration Time is not valid ISO-8601"}

      siwe.not_before != nil and not is_valid_iso8601?(siwe.not_before) ->
        {:error, "Not Before is not valid ISO-8601"}

      not is_eth_address?(siwe.address) ->
        {:error, "Invalid Ethereum address format"}

      true ->
        :ok
    end
  end

  @doc """
  Checks if a SIWE message has expired based on its expiration_time.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expiration_time: nil}), do: false

  def expired?(%__MODULE__{expiration_time: exp}) do
    case DateTime.from_iso8601(exp) do
      {:ok, dt, _} -> DateTime.compare(dt, DateTime.utc_now()) == :lt
      {:error, _} -> true
    end
  end

  @doc """
  Checks if a SIWE message is valid for use based on its not_before.
  """
  @spec not_yet_valid?(t()) :: boolean()
  def not_yet_valid?(%__MODULE__{not_before: nil}), do: false

  def not_yet_valid?(%__MODULE__{not_before: nb}) do
    case DateTime.from_iso8601(nb) do
      {:ok, dt, _} -> DateTime.compare(dt, DateTime.utc_now()) == :gt
      {:error, _} -> false
    end
  end

  @doc """
  Extracts a SIWE message from HTTP headers if present.
  """
  @spec from_headers([{String.t(), String.t()}]) :: {:ok, t()} | {:error, String.t()} | :not_found
  def from_headers(headers) do
    case List.keyfind(headers, @siwe_header, 0) do
      nil -> :not_found
      {_key, value} -> parse_message(value)
    end
  end

  defp optional_line(nil, _line), do: []
  defp optional_line(_value, line), do: [line]

  defp optional_resources([]), do: []
  defp optional_resources(resources), do: ["", "Resources:"] ++ Enum.map(resources, &"- #{&1}")

  defp extract_prefix([]), do: {:error, "empty message"}
  defp extract_prefix([first | rest]), do: {:ok, first, rest}

  defp extract_address([line | rest]) do
    if line =~ ~r/^0x[a-fA-F0-9]{40}$/ do
      {:ok, line, rest}
    else
      {:error, "expected address line, got: #{line}"}
    end
  end

  defp extract_address([_ | rest]), do: extract_address(rest)

  defp extract_statement(lines) do
    case lines do
      ["" | rest] ->
        {:ok, nil, [" " | rest]}

      [line | rest] ->
        if String.starts_with?("URI:", rest |> Enum.at(0, "")) do
          {:ok, nil, [line | rest]}
        else
          {:ok, line, rest}
        end

      [] ->
        {:ok, nil, []}
    end
  end

  defp extract_field(lines, prefix) do
    case Enum.find_index(lines, &String.starts_with?(&1, "#{prefix}: ")) do
      nil ->
        {:error, "field not found: #{prefix}"}

      idx ->
        value =
          lines
          |> Enum.at(idx)
          |> String.trim_leading("#{prefix}: ")

        rest = Enum.drop(lines, idx + 1)
        {:ok, value, rest}
    end
  end

  defp extract_optional_field(lines, prefix) do
    case Enum.find_index(lines, &String.starts_with?(&1, "#{prefix}: ")) do
      nil ->
        {:ok, nil, lines}

      idx ->
        value =
          lines
          |> Enum.at(idx)
          |> String.trim_leading("#{prefix}: ")

        rest = Enum.drop(lines, idx + 1)
        {:ok, value, rest}
    end
  end

  defp extract_resources(lines) do
    case lines do
      ["", "Resources:" | rest] ->
        Enum.take_while(rest, &String.starts_with?(&1, "- "))
        |> Enum.map(&String.trim_leading(&1, "- "))

      _ ->
        []
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "invalid integer: #{str}"}
    end
  end

  defp is_valid_iso8601?(str) do
    case DateTime.from_iso8601(str) do
      {:ok, _, _} -> true
      _ -> false
    end
  end

  defp is_eth_address?(addr) do
    addr =~ ~r/^0x[a-fA-F0-9]{40}$/
  end
end

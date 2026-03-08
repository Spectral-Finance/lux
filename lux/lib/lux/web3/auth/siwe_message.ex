defmodule Lux.Web3.Auth.SiweMessage do
  @moduledoc """
  Sign-In with Ethereum (EIP-4361) message generation and parsing.

  Generates and validates SIWE messages per https://eips.ethereum.org/EIPS/eip-4361
  """

  @enforce_keys [:domain, :address, :uri, :version, :chain_id, :nonce, :issued_at]
  defstruct [
    :domain,
    :address,
    :uri,
    :version,
    :chain_id,
    :nonce,
    :issued_at,
    :statement,
    :expiration_time,
    :not_before,
    :request_id,
    :resources
  ]

  @doc "Create a new SIWE message."
  def new(params) do
    %__MODULE__{
      domain: params[:domain],
      address: params[:address],
      uri: params[:uri],
      version: params[:version] || "1",
      chain_id: params[:chain_id] || 1,
      nonce: params[:nonce] || generate_nonce(),
      issued_at: params[:issued_at] || DateTime.utc_now() |> DateTime.to_iso8601(),
      statement: params[:statement],
      expiration_time: params[:expiration_time],
      not_before: params[:not_before],
      request_id: params[:request_id],
      resources: params[:resources]
    }
  end

  @doc "Convert SIWE message to EIP-4361 string format."
  def to_string(%__MODULE__{} = msg) do
    lines = [
      "#{msg.domain} wants you to sign in with your Ethereum account:",
      msg.address,
      ""
    ]

    lines = if msg.statement, do: lines ++ [msg.statement, ""], else: lines

    lines = lines ++ [
      "URI: #{msg.uri}",
      "Version: #{msg.version}",
      "Chain ID: #{msg.chain_id}",
      "Nonce: #{msg.nonce}",
      "Issued At: #{msg.issued_at}"
    ]

    lines = if msg.expiration_time, do: lines ++ ["Expiration Time: #{msg.expiration_time}"], else: lines
    lines = if msg.not_before, do: lines ++ ["Not Before: #{msg.not_before}"], else: lines
    lines = if msg.request_id, do: lines ++ ["Request ID: #{msg.request_id}"], else: lines

    lines = if msg.resources && length(msg.resources) > 0 do
      lines ++ ["Resources:"] ++ Enum.map(msg.resources, &("- #{&1}"))
    else
      lines
    end

    Enum.join(lines, "\n")
  end

  @doc "Parse an EIP-4361 message string."
  def parse(message_str) when is_binary(message_str) do
    lines = String.split(message_str, "\n")

    with {:ok, domain} <- parse_domain(Enum.at(lines, 0)),
         address when is_binary(address) <- Enum.at(lines, 1),
         fields <- parse_fields(lines) do
      {:ok, %__MODULE__{
        domain: domain,
        address: String.trim(address),
        uri: fields["URI"],
        version: fields["Version"] || "1",
        chain_id: parse_int(fields["Chain ID"], 1),
        nonce: fields["Nonce"],
        issued_at: fields["Issued At"],
        statement: parse_statement(lines),
        expiration_time: fields["Expiration Time"],
        not_before: fields["Not Before"],
        request_id: fields["Request ID"],
        resources: parse_resources(lines)
      }}
    end
  end

  @doc "Validate message fields (expiry, not_before, nonce format)."
  def validate(%__MODULE__{} = msg) do
    now = DateTime.utc_now()

    cond do
      msg.expiration_time && expired?(msg.expiration_time, now) ->
        {:error, :expired}
      msg.not_before && not_yet?(msg.not_before, now) ->
        {:error, :not_yet_valid}
      !valid_address?(msg.address) ->
        {:error, :invalid_address}
      !msg.nonce || String.length(msg.nonce) < 8 ->
        {:error, :invalid_nonce}
      true ->
        :ok
    end
  end

  def generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp parse_domain(line) do
    case Regex.run(~r/^(.+) wants you to sign in with your Ethereum account:$/, line || "") do
      [_, domain] -> {:ok, domain}
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_fields(lines) do
    lines
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/^([\w\s]+): (.+)$/, String.trim(line)) do
        [_, key, value] -> Map.put(acc, key, value)
        _ -> acc
      end
    end)
  end

  defp parse_statement(lines) do
    # Statement is between address line and first empty line after it
    lines = Enum.drop(lines, 2) # Skip domain + address
    case Enum.find_index(lines, &(&1 == "")) do
      0 -> nil # No statement
      nil -> nil
      idx ->
        statement_lines = Enum.slice(lines, 0, idx)
        case statement_lines do
          [] -> nil
          ["" | _] -> nil
          stmts -> Enum.join(stmts, "\n") |> String.trim()
        end
    end
  end

  defp parse_resources(lines) do
    case Enum.find_index(lines, &(String.trim(&1) == "Resources:")) do
      nil -> nil
      idx ->
        lines
        |> Enum.drop(idx + 1)
        |> Enum.take_while(&String.starts_with?(&1, "- "))
        |> Enum.map(&String.trim_leading(&1, "- "))
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp expired?(exp_str, now) do
    case DateTime.from_iso8601(exp_str) do
      {:ok, exp, _} -> DateTime.compare(now, exp) == :gt
      _ -> false
    end
  end

  defp not_yet?(nb_str, now) do
    case DateTime.from_iso8601(nb_str) do
      {:ok, nb, _} -> DateTime.compare(now, nb) == :lt
      _ -> false
    end
  end

  defp valid_address?(addr) when is_binary(addr) do
    String.match?(addr, ~r/^0x[0-9a-fA-F]{40}$/)
  end
  defp valid_address?(_), do: false
end

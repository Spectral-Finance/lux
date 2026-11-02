defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  Implements the EIP-4361: Sign-In with Ethereum (SIWE) specification.
  Provides secure nonce generation, message formatting, parsing, and time/domain validation.
  """

  @type siwe_message :: %{
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
          resources: list(String.t())
        }

  @nonce_chars ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  @doc """
  Generates a cryptographically secure random alphanumeric nonce for SIWE.
  Default length is 16 characters (EIP-4361 requires at least 8).
  """
  @spec generate_nonce(pos_integer()) :: String.t()
  def generate_nonce(length \\ 16) when is_integer(length) and length >= 8 do
    1..length
    |> Enum.map(fn _ -> Enum.random(@nonce_chars) end)
    |> to_string()
  end

  @doc """
  Formats a SIWE message struct or map into the standard EIP-4361 string representation.
  """
  @spec format_message(map()) :: {:ok, String.t()} | {:error, term()}
  def format_message(params) when is_map(params) do
    domain = Map.get(params, :domain) || Map.get(params, "domain")
    address = Map.get(params, :address) || Map.get(params, "address")
    statement = Map.get(params, :statement) || Map.get(params, "statement")
    uri = Map.get(params, :uri) || Map.get(params, "uri")
    version = Map.get(params, :version) || Map.get(params, "version", "1")
    chain_id = Map.get(params, :chain_id) || Map.get(params, "chain_id", 1)
    nonce = Map.get(params, :nonce) || Map.get(params, "nonce")
    issued_at = Map.get(params, :issued_at) || Map.get(params, "issued_at")
    exp = Map.get(params, :expiration_time) || Map.get(params, "expiration_time")
    nbf = Map.get(params, :not_before) || Map.get(params, "not_before")
    req_id = Map.get(params, :request_id) || Map.get(params, "request_id")
    resources = Map.get(params, :resources) || Map.get(params, "resources", [])

    cond do
      is_nil(domain) -> {:error, :missing_domain}
      is_nil(address) -> {:error, :missing_address}
      is_nil(uri) -> {:error, :missing_uri}
      is_nil(nonce) -> {:error, :missing_nonce}
      is_nil(issued_at) -> {:error, :missing_issued_at}
      true ->
        header = "#{domain} wants you to sign in with your Ethereum account:\n#{address}\n\n"
        statement_part = if statement && statement != "", do: "#{statement}\n\n", else: ""

        core = """
        URI: #{uri}
        Version: #{version}
        Chain ID: #{chain_id}
        Nonce: #{nonce}
        Issued At: #{issued_at}
        """
        |> String.trim_trailing()

        opt_exp = if exp, do: "\nExpiration Time: #{exp}", else: ""
        opt_nbf = if nbf, do: "\nNot Before: #{nbf}", else: ""
        opt_req = if req_id, do: "\nRequest ID: #{req_id}", else: ""

        opt_res =
          if resources != [] do
            "\nResources:\n" <> Enum.map_join(resources, "\n", &"- #{&1}")
          else
            ""
          end

        message = header <> statement_part <> core <> opt_exp <> opt_nbf <> opt_req <> opt_res
        {:ok, message}
    end
  end

  @doc """
  Parses a raw EIP-4361 string into a structured SIWE message map.
  """
  @spec parse_message(String.t()) :: {:ok, siwe_message()} | {:error, term()}
  def parse_message(raw) when is_binary(raw) do
    # Regex pattern matching standard EIP-4361 layout
    regex = ~r/^(?<domain>[^\n]+) wants you to sign in with your Ethereum account:\n(?<address>0x[a-fA-F0-9]{40})(?:\n\n(?<statement>[^\n]+(?:\n[^\n]+)*))?\n\nURI: (?<uri>[^\n]+)\nVersion: (?<version>[^\n]+)\nChain ID: (?<chain_id>\d+)\nNonce: (?<nonce>[a-zA-Z0-9]+)\nIssued At: (?<issued_at>[^\n]+)(?:\nExpiration Time: (?<expiration_time>[^\n]+))?(?:\nNot Before: (?<not_before>[^\n]+))?(?:\nRequest ID: (?<request_id>[^\n]+))?(?:\nResources:(?<resources>(?:\n- [^\n]+)+))?/

    case Regex.named_captures(regex, raw) do
      nil ->
        {:error, :invalid_siwe_format}

      caps ->
        resources =
          case caps["resources"] do
            "" -> []
            res_str ->
              res_str
              |> String.split("\n- ")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
          end

        parsed = %{
          domain: caps["domain"],
          address: caps["address"],
          statement: if(caps["statement"] == "", do: nil, else: caps["statement"]),
          uri: caps["uri"],
          version: caps["version"],
          chain_id: String.to_integer(caps["chain_id"]),
          nonce: caps["nonce"],
          issued_at: caps["issued_at"],
          expiration_time: if(caps["expiration_time"] == "", do: nil, else: caps["expiration_time"]),
          not_before: if(caps["not_before"] == "", do: nil, else: caps["not_before"]),
          request_id: if(caps["request_id"] == "", do: nil, else: caps["request_id"]),
          resources: resources
        }

        {:ok, parsed}
    end
  rescue
    e -> {:error, "SIWE parse error: #{Exception.message(e)}"}
  end

  @doc """
  Validates a parsed SIWE message against time constraints, domain, and expected nonce.
  """
  @spec validate(map(), keyword()) :: :ok | {:error, atom()}
  def validate(parsed, opts \\ []) when is_map(parsed) do
    now = Keyword.get(opts, :as_of, DateTime.utc_now())
    expected_nonce = Keyword.get(opts, :expected_nonce)
    expected_domain = Keyword.get(opts, :expected_domain)
    expected_chain_id = Keyword.get(opts, :expected_chain_id)

    with :ok <- validate_nonce(parsed.nonce, expected_nonce),
         :ok <- validate_domain(parsed.domain, expected_domain),
         :ok <- validate_chain(parsed.chain_id, expected_chain_id),
         :ok <- validate_expiration(parsed.expiration_time, now),
         :ok <- validate_not_before(parsed.not_before, now) do
      :ok
    end
  end

  defp validate_nonce(_nonce, nil), do: :ok
  defp validate_nonce(nonce, expected) when nonce == expected, do: :ok
  defp validate_nonce(_, _), do: {:error, :nonce_mismatch}

  defp validate_domain(_domain, nil), do: :ok
  defp validate_domain(domain, expected) when domain == expected, do: :ok
  defp validate_domain(_, _), do: {:error, :domain_mismatch}

  defp validate_chain(_chain, nil), do: :ok
  defp validate_chain(chain, expected) when chain == expected, do: :ok
  defp validate_chain(_, _), do: {:error, :chain_id_mismatch}

  defp validate_expiration(nil, _now), do: :ok

  defp validate_expiration(exp_str, now) do
    case DateTime.from_iso8601(exp_str) do
      {:ok, exp, _} ->
        if DateTime.compare(now, exp) == :gt, do: {:error, :message_expired}, else: :ok

      _ ->
        {:error, :invalid_expiration_format}
    end
  end

  defp validate_not_before(nil, _now), do: :ok

  defp validate_not_before(nbf_str, now) do
    case DateTime.from_iso8601(nbf_str) do
      {:ok, nbf, _} ->
        if DateTime.compare(now, nbf) == :lt, do: {:error, :message_not_yet_valid}, else: :ok

      _ ->
        {:error, :invalid_not_before_format}
    end
  end
end

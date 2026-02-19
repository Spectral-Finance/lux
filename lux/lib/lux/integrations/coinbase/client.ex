defmodule Lux.Integrations.Coinbase.Client do
  @moduledoc """
  HTTP client for Coinbase Advanced Trade API requests.

  Handles JWT-based authentication using ES256 (ECDSA P-256) signing,
  rate limiting, and error handling for all Coinbase API interactions.

  ## Authentication

  Each request requires a unique JWT token that includes:
  - `iss`: "cdp" (Coinbase Developer Platform)
  - `sub`: The API key name
  - `nbf`: Current timestamp
  - `exp`: Current timestamp + 120 seconds
  - `uri`: The formatted request URI (e.g., "GET api.coinbase.com/api/v3/brokerage/accounts")

  The JWT is signed with ES256 algorithm using the API secret key.

  ## Examples

      # Get accounts
      iex> Coinbase.Client.request(:get, "/accounts")
      {:ok, %{"accounts" => [...]}}

      # Create an order
      iex> Coinbase.Client.request(:post, "/orders", %{json: %{...}})
      {:ok, %{"order_id" => "...", "success" => true}}
  """

  require Logger

  @endpoint "https://api.coinbase.com/api/v3/brokerage"
  @jwt_lifetime_seconds 120

  @type request_opts :: %{
          optional(:json) => map(),
          optional(:params) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()}
        }

  @doc """
  Makes a request to the Coinbase Advanced Trade API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g., "/accounts", "/orders")
    * `opts` - Request options

  ## Options

    * `:json` - Request body for POST/PUT requests
    * `:params` - Query parameters for GET requests
    * `:headers` - Additional headers
    * `:plug` - A plug for testing

  ## Returns

    * `{:ok, map()}` - Successful response body
    * `{:error, term()}` - Error details
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    url = @endpoint <> path

    case generate_jwt(method |> to_string() |> String.upcase(), "/api/v3/brokerage" <> path) do
      {:ok, jwt} ->
        base_opts = [
          method: method,
          url: url,
          headers: [
            {"Authorization", "Bearer #{jwt}"},
            {"Content-Type", "application/json"}
          ],
          retry: false
        ]

        base_opts =
          if opts[:json], do: base_opts ++ [json: opts[:json]], else: base_opts

        base_opts =
          if opts[:params], do: base_opts ++ [params: opts[:params]], else: base_opts

        base_opts
        |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
        |> maybe_add_plug(opts[:plug])
        |> Req.new()
        |> Req.request()
        |> handle_response()

      {:error, reason} ->
        {:error, {:auth_error, reason}}
    end
  end

  @doc """
  Generates a JWT token for authenticating with the Coinbase API.

  ## Parameters

    * `method` - HTTP method (e.g., "GET", "POST")
    * `path` - API path (e.g., "/api/v3/brokerage/accounts")

  ## Returns

    * `{:ok, jwt_token}` - Successfully generated JWT
    * `{:error, reason}` - Failed to generate JWT
  """
  @spec generate_jwt(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_jwt(method, path) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret() do
      now = System.system_time(:second)
      nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      uri = "#{method} api.coinbase.com#{path}"

      header = %{
        "alg" => "ES256",
        "typ" => "JWT",
        "kid" => api_key,
        "nonce" => nonce
      }

      payload = %{
        "iss" => "cdp",
        "sub" => api_key,
        "nbf" => now,
        "exp" => now + @jwt_lifetime_seconds,
        "uri" => uri
      }

      try do
        encoded_header = Base.url_encode64(Jason.encode!(header), padding: false)
        encoded_payload = Base.url_encode64(Jason.encode!(payload), padding: false)
        signing_input = "#{encoded_header}.#{encoded_payload}"

        # Parse the EC private key and sign
        [pem_entry] = :public_key.pem_decode(api_secret)
        private_key = :public_key.pem_entry_decode(pem_entry)

        signature = :public_key.sign(signing_input, :sha256, private_key)

        # Convert DER signature to raw R||S format for JWT
        raw_signature = der_to_raw(signature)
        encoded_signature = Base.url_encode64(raw_signature, padding: false)

        {:ok, "#{signing_input}.#{encoded_signature}"}
      rescue
        e -> {:error, "JWT generation failed: #{inspect(e)}"}
      end
    end
  end

  # Converts a DER-encoded ECDSA signature to raw R||S format (64 bytes for P-256)
  defp der_to_raw(der_signature) do
    {:ok, {r, s}} = decode_der_signature(der_signature)
    pad_integer(r, 32) <> pad_integer(s, 32)
  end

  defp decode_der_signature(<<0x30, _rest::binary>> = der) do
    case der do
      <<0x30, total_len, rest::binary-size(total_len)>> ->
        {r, rest2} = decode_der_integer(rest)
        {s, _} = decode_der_integer(rest2)
        {:ok, {r, s}}

      _ ->
        {:error, :invalid_der}
    end
  end

  defp decode_der_integer(<<0x02, len, value::binary-size(len), rest::binary>>) do
    # Strip leading zero padding if present
    stripped = strip_leading_zeros(value)
    {stripped, rest}
  end

  defp strip_leading_zeros(<<0x00, rest::binary>>) when byte_size(rest) > 0, do: rest
  defp strip_leading_zeros(value), do: value

  defp pad_integer(bytes, target_size) when byte_size(bytes) >= target_size do
    binary_part(bytes, byte_size(bytes) - target_size, target_size)
  end

  defp pad_integer(bytes, target_size) do
    padding_size = target_size - byte_size(bytes)
    :binary.copy(<<0>>, padding_size) <> bytes
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :invalid_credentials}
  end

  defp handle_response({:ok, %{status: 403}}) do
    {:error, :forbidden}
  end

  defp handle_response({:ok, %{status: 429} = response}) do
    retry_after =
      case Req.Response.get_header(response, "retry-after") do
        [value | _] -> String.to_integer(value)
        _ -> 60
      end

    {:error, {:rate_limited, retry_after}}
  end

  defp handle_response({:ok, %{status: status, body: %{"error" => error, "message" => message}}}) do
    {:error, {status, "#{error}: #{message}"}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) when is_map(body) do
    message = body["message"] || body["error"] || inspect(body)
    {:error, {status, message}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    {:error, {:transport_error, reason}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp get_api_key do
    case Lux.Config.coinbase_api_key() do
      nil -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  rescue
    _ -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    case Lux.Config.coinbase_api_secret() do
      nil -> {:error, :missing_api_secret}
      secret -> {:ok, secret}
    end
  rescue
    _ -> {:error, :missing_api_secret}
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end

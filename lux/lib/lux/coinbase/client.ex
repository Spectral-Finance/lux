defmodule Lux.Coinbase.Client do
  @moduledoc """
  Client for the Coinbase Exchange REST API.

  Reference: https://docs.cloud.coinbase.com/exchange/reference

  Authentication uses the Coinbase Exchange API key/secret/passphrase scheme:
  every request is signed with HMAC-SHA256 over `timestamp + method + path + body`
  using the base64-decoded API secret, then base64-encoded.

  Configuration (application `:lux`):
    * :coinbase_api_key    - API key (required for authenticated endpoints)
    * :coinbase_secret     - base64-encoded API secret (required)
    * :coinbase_passphrase - API passphrase (required)
    * :coinbase_api_url    - base URL (defaults to https://api.exchange.coinbase.com)
    * :coinbase_req_options - extra options merged into `Req.new/1`, e.g.
                              `plug: {Req.Test, Lux.Coinbase.Client}` in tests
  """

  defp base_url do
    Application.get_env(:lux, :coinbase_api_url) || "https://api.exchange.coinbase.com"
  end

  @doc """
  Makes a request to the Coinbase Exchange API.

  By default the request is authenticated with the API key/secret/passphrase.
  Pass `auth?: false` in `opts` for public endpoints (e.g. product ticker).

  Returns `{:ok, body}` with the decoded response body on success, or
  `{:error, reason}` on failure. `reason` is a map containing `:status` and
  `:message` for HTTP error responses, or a binary for transport errors.
  """
  def request(method, path, body \\ nil, opts \\ %{}) do
    opts = Map.new(opts)
    auth? = Map.get(opts, :auth?, true)
    method_str = method |> Atom.to_string() |> String.downcase()

    req_headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]

    if auth? do
      config = fetch_config()

      with {:ok, api_key} <- required(config, :coinbase_api_key),
           {:ok, secret} <- required(config, :coinbase_secret),
           {:ok, passphrase} <- required(config, :coinbase_passphrase) do
        timestamp = (opts[:timestamp] || System.system_time(:second)) |> Integer.to_string()
        body_str = encode_body(body)
        signature = sign(timestamp, method_str, path, body_str, secret)

        req_headers = req_headers ++ [
          {"CB-ACCESS-TIMESTAMP", timestamp},
          {"CB-ACCESS-KEY", api_key},
          {"CB-ACCESS-SIGN", signature},
          {"CB-ACCESS-PASSPHRASE", passphrase}
        ]

        send_request(method_str, path, body, opts, req_headers)
      end
    else
      send_request(method_str, path, body, opts, req_headers)
    end
  end

  defp send_request(method_str, path, body, opts, req_headers) do
    client =
      Req.new(
        [
          headers: req_headers,
          max_retries: 0
        ]
        |> Keyword.merge(opts[:req_options] || Application.get_env(:lux, :coinbase_req_options, []))
      )

    request_opts =
      [method: method_str, url: base_url() <> path] ++ body_or_params(method_str, body)

    case Req.request(client, request_opts) do
      {:ok, %Req.Response{status: status, body: body}} ->
        handle_response(status, body)

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "Coinbase transport error: #{inspect(reason)}"}

      {:error, error} ->
        {:error, "Coinbase request error: #{inspect(error)}"}
    end
  end

  @doc """
  Signs a Coinbase Exchange API request.

  Returns the base64-encoded HMAC-SHA256 signature of
  `timestamp <> method <> path <> body` using the base64-decoded `secret`.

  A fixed `timestamp` can be supplied for deterministic tests.
  """
  def sign(timestamp, method, path, body, secret) do
    decoded_secret = Base.decode64!(secret)
    message = "#{timestamp}#{String.upcase(method)}#{path}#{body}"

    :crypto.mac(:hmac, :sha256, decoded_secret, message)
    |> Base.encode64()
  end

  defp fetch_config do
    %{
      coinbase_api_key: Application.get_env(:lux, :coinbase_api_key),
      coinbase_secret: Application.get_env(:lux, :coinbase_secret),
      coinbase_passphrase: Application.get_env(:lux, :coinbase_passphrase)
    }
  end

  defp required(config, key) do
    case Map.fetch(config, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ ->
        {:error, "Coinbase #{inspect(key)} is not configured"}
    end
  end

  defp encode_body(nil), do: ""
  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body) when is_map(body), do: Jason.encode!(body)

  defp body_or_params("get", _params), do: []
  defp body_or_params("delete", nil), do: []
  defp body_or_params(_method, body) when body != nil and body != "", do: [json: body]
  defp body_or_params(_method, _body), do: []

  defp handle_response(200, body) when is_map(body) or is_list(body), do: {:ok, body}
  defp handle_response(201, body) when is_map(body) or is_list(body), do: {:ok, body}

  defp handle_response(status, body) do
    message =
      case body do
        %{"message" => message} when is_binary(message) -> message
        %{"error" => message} when is_binary(message) -> message
        binary when is_binary(binary) -> binary
        _ -> inspect(body)
      end

    {:error, %{"status" => status, "message" => message}}
  end
end

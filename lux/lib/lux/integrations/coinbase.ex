defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Common settings and functions for Coinbase Advanced Trade API integration.

  Uses JWT-based authentication as required by Coinbase Advanced Trade API.
  """

  @base_url "https://api.coinbase.com"
  @sandbox_url "https://api-public.sandbox.exchange.coinbase.com"

  @doc """
  Returns the base URL for Coinbase API.
  Uses sandbox if :coinbase_sandbox is enabled in config.
  """
  def base_url do
    if Application.get_env(:lux, :coinbase_sandbox, false) do
      @sandbox_url
    else
      @base_url
    end
  end

  @doc """
  Returns the configured Coinbase API key name.
  """
  def api_key_name do
    Application.get_env(:lux, :api_keys, [])[:coinbase_api_key_name] ||
      System.get_env("COINBASE_API_KEY_NAME") ||
      raise "Coinbase API key name not configured."
  end

  @doc """
  Returns the configured Coinbase API private key.
  """
  def api_private_key do
    Application.get_env(:lux, :api_keys, [])[:coinbase_api_private_key] ||
      System.get_env("COINBASE_API_PRIVATE_KEY") ||
      raise "Coinbase API private key not configured."
  end

  @doc """
  Generates a JWT token for authenticating with Coinbase Advanced Trade API.
  """
  def build_jwt(method, path) do
    key_name = api_key_name()
    private_key_pem = api_private_key()

    timestamp = System.system_time(:second)
    uri = "#{method} #{String.replace(base_url(), ~r/https?:\/\/[^\/]+/, "")}#{path}"

    payload = %{
      "sub" => key_name,
      "iss" => "cdp",
      "nbf" => timestamp,
      "exp" => timestamp + 120,
      "uri" => uri
    }

    # Parse the EC private key
    {:ok, jwk} = JOSE.JWK.from_pem(private_key_pem) |> case do
      jwk = %JOSE.JWK{} -> {:ok, jwk}
      _ -> {:error, :invalid_key}
    end

    {_alg, token} = JOSE.JWT.sign(jwk, %{"alg" => "ES256"}, payload)
    |> JOSE.JWS.compact()
    token
  rescue
    _ -> raise "Failed to generate Coinbase JWT token"
  end

  @doc """
  Makes an authenticated GET request to Coinbase API.
  """
  def get(path, params \\ %{}) do
    jwt = build_jwt("GET", path)
    query = if map_size(params) > 0, do: "?" <> URI.encode_query(params), else: ""
    url = base_url() <> path <> query

    headers = [
      {"Authorization", "Bearer #{jwt}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case Req.get(url, headers: headers) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Makes an authenticated POST request to Coinbase API.
  """
  def post(path, body \\ %{}) do
    jwt = build_jwt("POST", path)
    url = base_url() <> path

    headers = [
      {"Authorization", "Bearer #{jwt}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case Req.post(url, headers: headers, json: body) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 -> {:ok, resp_body}
      {:ok, %{status: status, body: resp_body}} -> {:error, {status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Public endpoint GET (no auth required).
  """
  def get_public(path, params \\ %{}) do
    query = if map_size(params) > 0, do: "?" <> URI.encode_query(params), else: ""
    url = base_url() <> path <> query

    case Req.get(url, headers: [{"Content-Type", "application/json"}]) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end

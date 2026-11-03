defmodule Lux.Integrations.Coinbase.RestClient do
  @moduledoc """
  HTTP Client for Coinbase Advanced Trade REST API v3.
  Supports both Production and Sandbox environments.
  """

  alias Lux.Integrations.Coinbase.Signer

  @prod_base_url "https://api.coinbase.com"
  @sandbox_base_url "https://api-public.sandbox.exchange.coinbase.com"

  @type config :: %{
          api_key: String.t(),
          secret_key: String.t(),
          sandbox?: boolean()
        }

  @doc """
  Returns base URL for Coinbase API.
  """
  @spec base_url(boolean()) :: String.t()
  def base_url(sandbox? \\ false) do
    if sandbox?, do: @sandbox_base_url, else: @prod_base_url
  end

  @doc """
  Prepares a signed GET request.
  """
  @spec prepare_signed_get(config(), String.t(), map()) :: {String.t(), list()}
  def prepare_signed_get(config, endpoint, params \\ %{}) do
    base = base_url(config.sandbox?)

    query_str =
      if map_size(params) > 0,
        do: "?" <> URI.encode_query(params),
        else: ""

    request_path = endpoint <> query_str
    headers = Signer.auth_headers(config.api_key, config.secret_key, "GET", request_path, "")
    full_url = "#{base}#{request_path}"

    {full_url, headers}
  end

  @doc """
  Prepares a signed POST request.
  """
  @spec prepare_signed_post(config(), String.t(), map() | String.t()) :: {String.t(), String.t(), list()}
  def prepare_signed_post(config, endpoint, payload) do
    base = base_url(config.sandbox?)
    body = if is_binary(payload), do: payload, else: Jason.encode!(payload)
    headers = Signer.auth_headers(config.api_key, config.secret_key, "POST", endpoint, body)
    full_url = "#{base}#{endpoint}"

    {full_url, body, headers}
  end

  @doc """
  Parses Coinbase REST response payload or formats standardized errors.
  """
  @spec parse_response({:ok, map()} | {:error, term()}) :: {:ok, map()} | {:error, term()}
  def parse_response({:ok, %{"error" => err, "message" => msg}}) do
    {:error, %{error: err, message: msg}}
  end

  def parse_response({:ok, %{"error_response" => %{"message" => msg}}}) do
    {:error, %{error: "API_ERROR", message: msg}}
  end

  def parse_response({:ok, data}), do: {:ok, data}
  def parse_response({:error, reason}), do: {:error, reason}
end

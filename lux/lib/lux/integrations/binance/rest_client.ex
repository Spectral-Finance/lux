defmodule Lux.Integrations.Binance.RestClient do
  @moduledoc """
  HTTP Client for Binance Spot and USDⓈ-M Futures REST APIs.
  Supports both Production and Testnet environments.
  """

  alias Lux.Integrations.Binance.Signer

  @spot_prod_url "https://api.binance.com"
  @spot_testnet_url "https://testnet.binance.vision"
  @futures_prod_url "https://fapi.binance.com"
  @futures_testnet_url "https://testnet.binancefuture.com"

  @type config :: %{
          api_key: String.t(),
          secret_key: String.t(),
          testnet?: boolean()
        }

  @doc """
  Returns base URL for Spot API.
  """
  @spec spot_base_url(boolean()) :: String.t()
  def spot_base_url(testnet? \\ false) do
    if testnet?, do: @spot_testnet_url, else: @spot_prod_url
  end

  @doc """
  Returns base URL for USDⓈ-M Futures API.
  """
  @spec futures_base_url(boolean()) :: String.t()
  def futures_base_url(testnet? \\ false) do
    if testnet?, do: @futures_testnet_url, else: @futures_prod_url
  end

  @doc """
  Prepares a signed GET request url and headers.
  """
  @spec prepare_signed_get(config(), :spot | :futures, String.t(), map()) :: {String.t(), list()}
  def prepare_signed_get(config, market_type, endpoint, params) do
    base = if market_type == :spot, do: spot_base_url(config.testnet?), else: futures_base_url(config.testnet?)
    signed_query = Signer.prepare_signed_query(params, config.secret_key)
    full_url = "#{base}#{endpoint}?#{signed_query}"
    headers = Signer.auth_headers(config.api_key)

    {full_url, headers}
  end

  @doc """
  Prepares a signed POST request url, body, and headers.
  """
  @spec prepare_signed_post(config(), :spot | :futures, String.t(), map()) :: {String.t(), String.t(), list()}
  def prepare_signed_post(config, market_type, endpoint, params) do
    base = if market_type == :spot, do: spot_base_url(config.testnet?), else: futures_base_url(config.testnet?)
    signed_body = Signer.prepare_signed_query(params, config.secret_key)
    full_url = "#{base}#{endpoint}"
    headers = Signer.auth_headers(config.api_key)

    {full_url, signed_body, headers}
  end

  @doc """
  Parses Binance REST response payload or formats standardized errors.
  """
  @spec parse_response({:ok, map()} | {:error, term()}) :: {:ok, map()} | {:error, term()}
  def parse_response({:ok, %{"code" => code, "msg" => msg}}) when is_integer(code) and code < 0 do
    {:error, %{code: code, message: msg}}
  end

  def parse_response({:ok, data}), do: {:ok, data}
  def parse_response({:error, reason}), do: {:error, reason}
end

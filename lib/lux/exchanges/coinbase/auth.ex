defmodule Lux.Exchanges.Coinbase.Auth do
  @moduledoc """
  Authentication module for Coinbase API requests using HMAC-SHA256.
  """

  @doc """
  Signs a request with Coinbase API authentication headers.
  """
  def sign_request(method, path, body, timestamp) do
    api_key = get_api_key()
    secret = get_api_secret()
    passphrase = get_passphrase()

    message = "#{timestamp}#{method}#{path}#{body}"
    signature = sign_message(message, secret)

    [
      {"CB-ACCESS-KEY", api_key},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", to_string(timestamp)},
      {"CB-ACCESS-PASSPHRASE", passphrase}
    ]
  end

  @doc """
  Gets the API key from configuration.
  """
  def get_api_key do
    Application.get_env(:lux, :coinbase_api_key) ||
      System.get_env("COINBASE_API_KEY") ||
      raise "Coinbase API key not configured"
  end

  @doc """
  Gets the API secret from configuration.
  """
  def get_api_secret do
    Application.get_env(:lux, :coinbase_api_secret) ||
      System.get_env("COINBASE_API_SECRET") ||
      raise "Coinbase API secret not configured"
  end

  @doc """
  Gets the passphrase from configuration.
  """
  def get_passphrase do
    Application.get_env(:lux, :coinbase_passphrase) ||
      System.get_env("COINBASE_PASSPHRASE") ||
      raise "Coinbase passphrase not configured"
  end

  defp sign_message(message, secret) do
    :crypto.mac(:hmac, :sha256, Base.decode64!(secret), message)
    |> Base.encode64()
  end
end
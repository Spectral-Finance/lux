defmodule Lux.Integrations.Binance do
  @base_url "https://api.binance.com"

  def headers, do: [{"Content-Type", "application/json"}]

  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  def add_auth_header(%Lux.Lens{} = lens) do
    key = Application.get_env(:lux, :api_keys)[:binance]
    %{lens | headers: lens.headers ++ [{"X-MBX-APIKEY", key}]}
  end

  def base_url, do: @base_url
end

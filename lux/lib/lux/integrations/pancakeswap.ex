defmodule Lux.Integrations.PancakeSwap do
  @base_url "https://api.pancakeswap.info/api/v2"

  def headers, do: [{"Content-Type", "application/json"}]

  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  def add_auth_header(%Lux.Lens{} = lens), do: lens

  def base_url, do: @base_url
end

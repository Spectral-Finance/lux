defmodule Lux.Config.OpenRouter do
  @moduledoc """
  Configuration for OpenRouter integration with Lux.
  """

  @base_url "https://api.openrouter.com/v1"

  def config(api_key) do
    %{
      base_url: @base_url,
      api_key: api_key
    }
  end
end
# Lines 1-14 of lux/config/open_router.exs
defmodule Lux.Config.OpenRouter do
  @moduledoc """
  Configuration for OpenRouter integration with Lux.
  """

  import OpenRouter, only: [api_call: 2]

  @base_url System.get_env("OPENROUTER_API_URL") || "https://api.openrouter.com/v1"

  def config(api_key) do
    %{
      base_url: @base_url,
      api_key: api_key,
      timeout: 5000
    }
  end
end

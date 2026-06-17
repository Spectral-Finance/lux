defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Common settings and functions for Telegram Bot API integration.
  """

  @doc """
  Common headers for Telegram API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Telegram API calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_url/1
  }

  @doc """
  Injects the Telegram bot token into the API URL.
  Telegram requires the bot token in the URL path.
  """
  @spec add_auth_url(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_url(%Lux.Lens{} = lens) do
    api_keys = Application.get_env(:lux, :api_keys) || []
    token = api_keys[:telegram] || System.get_env("TELEGRAM_BOT_TOKEN") || "TEST_TOKEN"
    
    new_url = String.replace(lens.url, "<token>", token)
    %{lens | url: new_url}
  end
end
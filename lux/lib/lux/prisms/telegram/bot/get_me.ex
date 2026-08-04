defmodule Lux.Prisms.Telegram.Bot.GetMe do
  @moduledoc """
  A prism for fetching basic information about the bot.
  """
  use Lux.Prism

  alias Lux.Integrations.Telegram.Client

  def prism do
    %Lux.Prism{
      id: "telegram-get-me",
      name: "Get Telegram Bot Info",
      description: "Returns basic information about the bot.",
      handler: &handler/2
    }
  end

  def handler(_input, _ctx) do
    case Client.request(:get, "/getMe") do
      {:ok, %{"result" => result}} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

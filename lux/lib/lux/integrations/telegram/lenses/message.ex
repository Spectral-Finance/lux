defmodule Lux.Integrations.Telegram.Lenses.Message do
  @moduledoc """
  Lens for processing Telegram Message updates.
  """

  require Logger

  alias Lux.Integrations.Telegram.Client

  @type message :: %{
    required(:message_id) => integer(),
    required(:chat) => %{required(:id) => integer()},
    optional(:text) => String.t()
  }

  @doc """
  Processes a Telegram Message update.

  ## Parameters

    * `update` - The Telegram Update containing the Message

  ## Examples

      # Process a message
      iex> Lux.Integrations.Telegram.Lenses.Message.process(%{
      ...>   update_id: 123,
      ...>   message: %{
      ...>     message_id: 456,
      ...>     chat: %{id: 789},
      ...>     text: "Hello!"
      ...>   }
      ...> })
      {:ok, %{"message_id" => 456}}
  """
  @spec process(map()) :: {:ok, map()} | {:error, term()}
  def process(%{update_id: _, message: %{} = message}) do
    case Client.request(:post, "/sendMessage", %{
      token: Lux.Config.telegram_bot_token(),
      json: %{chat_id: message.chat.id, text: message.text}
    }) do
      {:ok, response} -> {:ok, response["result"]}
      {:error, reason} -> {:error, reason}
    end
  end

  def process(_), do: {:error, :invalid_update}

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp handle_response({:ok, %{"ok" => true, "result" => result}}), do: {:ok, result}
  defp handle_response({:ok, _}), do: {:error, :unknown_error}
  defp handle_response({:error, reason}), do: {:error, reason}
end
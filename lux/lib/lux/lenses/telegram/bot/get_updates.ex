import Telegram.Client
import Telegram.Integration

defmodule Lux.Lenses.Telegram.Bot.GetUpdates do
  @moduledoc """
  Lens for fetching updates from a Telegram bot.
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:timeout) => integer()
  }

  @doc """
  Fetches updates from the Telegram Bot API.

  ## Parameters

    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required)
    * `:timeout` - Timeout for the request in milliseconds

  ## Examples

      # Get updates
      iex> Lux.Lenses.Telegram.Bot.GetUpdates.get(%{
      ...>   token: "your_bot_token"
      ...> })
      {:ok, %{"ok" => true, "result" => [%{"message_id" => 123}]}}

  """
  @spec get(request_opts()) :: {:ok, map()} | {:error, term()}
  def get(opts \\ %{}) do
    token = opts[:token] || Lux.Config.telegram_bot_token()
    url = @endpoint <> token <> "/getUpdates"

    [
      method: :get,
      url: url,
      headers: [
        {"Content-Type", "application/json"}
      ],
      timeout: opts[:timeout]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status == 200 ->
        {:ok, response.body}

      {:ok, %{status: _}} ->
        {:error, :bad_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_plug(plug, nil), do: plug
  defp maybe_add_plug(_, plug), do: plug

def transform(response) do
  case response do
    {:ok, %{"result" => messages}} ->
      Enum.map(messages, fn message ->
        %{
          message_id: message["message_id"],
          chat_id: message["chat"]["id"],
          text: message["text"]
        }
      end)

    _ ->
      []
  end
end

defp transform_plug(plug) do
  plug
end

Show the OLD lines to replace and the NEW replacement.
Change ONLY what is needed. Match indentation exactly.

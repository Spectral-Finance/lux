defmodule Lux.Integrations.Telegram.WebhookHandler do
  @moduledoc """
  Handles incoming Telegram webhook requests.
  """

  require Logger

  @doc """
  Processes an incoming webhook request.

  ## Parameters

    * `conn` - Plug.Conn struct containing the request data

  ## Examples

      # Process a webhook request
      iex> WebhookHandler.handle(conn)
      {:ok, %{"message" => "Webhook processed successfully"}}
  """
  @spec handle(Plug.Conn.t()) :: {:ok, map()} | {:error, term()}
  def handle(conn) do
    case conn.method do
      "POST" ->
        process_webhook(conn)

      defp process_webhook(conn) do
        import Phoenix.json_library()
        import Lux.Config

        body = conn.body_params

        chat_id = Map.get(body, "message", %{})["chat"]["id"]
        text = Map.get(body, "message", %{})["text"]

        Logger.info("Processing webhook with chat ID: #{chat_id} and text: #{text}")

        case Lux.Integrations.Telegram.Client.request(:post, "/sendMessage", %{
          token: Lux.Config.telegram_bot_token(),
          json: %{chat_id: chat_id, text: text}
        }) do
          {:ok, _response} ->
            Logger.info("Webhook processed successfully")
            {:ok, %{"message" => "Webhook processed successfully"}}

          {:error, error} ->
            Logger.error("Failed to process webhook: #{inspect(error)}")
            {:error, :internal_error}
        end
      end

      def handle_update(conn) do
        import Phoenix.json_library()
        import Lux.Config

        body = conn.body_params

        chat_id = Map.get(body, "message", %{})["chat"]["id"]
        text = Map.get(body, "message", %{})["text"]

        Logger.info("Processing update with chat ID: #{chat_id} and text: #{text}")

        case Lux.Integrations.Telegram.Client.request(:post, "/sendMessage", %{
          token: Lux.Config.telegram_bot_token(),
          json: %{chat_id: chat_id, text: text}
        }) do
          {:ok, _response} ->
            Logger.info("Update processed successfully")
            {:ok, %{"message" => "Update processed successfully"}}

          {:error, error} ->
            Logger.error("Failed to process update: #{inspect(error)}")
            {:error, :internal_error}
        end
      end

    {:error, error} ->
      Logger.error("Failed to process update: #{inspect(error)}")
      {:error, :internal_error}
  end
end
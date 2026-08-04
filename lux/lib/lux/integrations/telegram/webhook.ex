defmodule Lux.Integrations.Telegram.Webhook do
  @moduledoc """
  A Plug to handle incoming Telegram Webhooks.
  Verifies the `X-Telegram-Bot-Api-Secret-Token` and dispatches updates to a handler.
  """
  import Plug.Conn
  require Logger

  @doc """
  Initializes the plug options.
  Requires a `:secret_token` string or function that returns a string,
  and a `:handler` module that exports `handle_update/1`.
  """
  def init(opts) do
    secret_token = Keyword.get(opts, :secret_token) || raise ArgumentError, "Missing required option :secret_token"
    handler = Keyword.get(opts, :handler) || raise ArgumentError, "Missing required option :handler"

    %{secret_token: secret_token, handler: handler}
  end

  @doc """
  Executes the plug. Validates the webhook secret and delegates the payload to the handler.
  """
  def call(conn, %{secret_token: secret_token, handler: handler}) do
    expected_token = if is_function(secret_token), do: secret_token.(), else: secret_token
    
    case get_req_header(conn, "x-telegram-bot-api-secret-token") do
      [^expected_token] ->
        process_update(conn, handler)

      _ ->
        Logger.warning("Telegram Webhook received invalid or missing secret token")
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end

  defp process_update(conn, handler) do
    # Assuming standard Plug.Parsers has already parsed the JSON body into conn.body_params
    update = conn.body_params

    try do
      if function_exported?(handler, :handle_update, 1) do
        handler.handle_update(update)
      else
        Logger.warning("Telegram Webhook Handler #{inspect(handler)} does not export handle_update/1")
      end
    rescue
      e ->
        Logger.error("Error in Telegram webhook handler: #{Exception.message(e)}")
    end

    conn
    |> send_resp(200, "OK")
    |> halt()
  end
end

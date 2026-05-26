defmodule Lux.Integrations.Telegram.Webhook do
  @moduledoc """
  A Plug to handle Telegram webhooks.
  """

  import Plug.Conn
  require Logger

  def init(opts) do
    %{
      handler: Keyword.fetch!(opts, :handler),
      secret_token: Keyword.get(opts, :secret_token)
    }
  end

  def call(conn, opts) do
    case validate_secret(conn, opts.secret_token) do
      :ok ->
        handle_webhook(conn, opts.handler)
      {:error, :unauthorized} ->
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end

  defp validate_secret(_conn, nil), do: :ok
  defp validate_secret(conn, secret_token) do
    case get_req_header(conn, "x-telegram-bot-api-secret-token") do
      [^secret_token] -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  defp handle_webhook(conn, handler) do
    {:ok, body, conn} = read_body(conn)
    update = Jason.decode!(body)
    
    dispatch_update(update, handler)

    conn
    |> send_resp(200, "OK")
    |> halt()
  end

  defp dispatch_update(update, handler) when is_function(handler, 1) do
    handler.(update)
  end

  defp dispatch_update(update, {module, function}) do
    apply(module, function, [update])
  end
end

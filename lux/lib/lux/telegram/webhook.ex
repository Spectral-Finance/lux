defmodule Lux.Telegram.Webhook do
  @moduledoc """
  Plug endpoint for receiving and processing Telegram Bot API webhook updates.
  Supports secret token verification via `X-Telegram-Bot-Api-Secret-Token` header.
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  @doc """
  Sets up webhook URL and options via `Lux.Telegram.Client`.
  """
  def set_webhook(client_or_url, url_or_opts \\ [], opts \\ []) do
    Lux.Telegram.Client.set_webhook(client_or_url, url_or_opts, opts)
  end

  @doc """
  Deletes the current webhook via `Lux.Telegram.Client`.
  """
  def delete_webhook(client_or_opts \\ [], opts \\ []) do
    Lux.Telegram.Client.delete_webhook(client_or_opts, opts)
  end

  @doc """
  Retrieves current webhook information via `Lux.Telegram.Client`.
  """
  def get_webhook_info(client_or_opts \\ []) do
    Lux.Telegram.Client.get_webhook_info(client_or_opts)
  end


  @impl true
  def init(opts) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}

    secret_token =
      cond do
        is_binary(opts_map[:secret_token]) and opts_map[:secret_token] != "" ->
          opts_map[:secret_token]

        is_binary(opts_map["secret_token"]) and opts_map["secret_token"] != "" ->
          opts_map["secret_token"]

        true ->
          fetch_config_secret_token()
      end

    handler = Map.get(opts_map, :handler)
    path = Map.get(opts_map, :path)

    %{
      secret_token: secret_token,
      handler: handler,
      path: path
    }
  end

  @impl true
  def call(conn, opts) do
    if secret_token_valid?(conn, opts.secret_token) do
      handle_update(conn, opts)
    else
      unauthorized(conn)
    end
  end

  defp secret_token_valid?(_conn, nil), do: true
  defp secret_token_valid?(_conn, ""), do: true

  defp secret_token_valid?(conn, expected_token) when is_binary(expected_token) do
    case get_req_header(conn, "x-telegram-bot-api-secret-token") do
      [header_token] -> Plug.Crypto.secure_compare(header_token, expected_token)
      _ -> false
    end
  end

  defp handle_update(conn, opts) do
    with {:ok, payload} <- parse_payload(conn),
         {:ok, signal} <- Lux.Signals.TelegramUpdate.new(payload),
         :ok <- dispatch_signal(signal, opts.handler) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{ok: true}))
    else
      {:error, :malformed_json} ->
        bad_request(conn, "Malformed JSON")

      {:error, :empty_body} ->
        bad_request(conn, "Empty request body")

      {:error, :invalid_payload} ->
        bad_request(conn, "Invalid payload")

      {:error, :read_body_error} ->
        bad_request(conn, "Invalid payload")

      {:error, :invalid_update} ->
        bad_request(conn, "Invalid update payload")

      {:error, %{schema_errors: _}} ->
        bad_request(conn, "Invalid update payload")

      {:error, validation_errors} when is_list(validation_errors) ->
        bad_request(conn, "Invalid update payload")

      {:error, reason} ->
        Logger.error("Webhook handler failed: #{inspect(reason)}")
        server_error(conn, "Handler error")
    end
  end

  defp parse_payload(%Plug.Conn{body_params: %{"update_id" => _} = params}), do: {:ok, params}
  defp parse_payload(%Plug.Conn{body_params: %{update_id: _} = params}), do: {:ok, params}

  defp parse_payload(%Plug.Conn{body_params: params})
       when is_map(params) and not is_struct(params) and map_size(params) > 0,
       do: {:ok, params}

  defp parse_payload(conn) do
    case read_body(conn) do
      {:ok, "", _conn} ->
        {:error, :empty_body}

      {:ok, body, _conn} ->
        case Jason.decode(body) do
          {:ok, map} when is_map(map) and map_size(map) > 0 -> {:ok, map}
          {:ok, map} when is_map(map) -> {:error, :invalid_payload}
          {:ok, _non_map} -> {:error, :invalid_payload}
          {:error, _decode_error} -> {:error, :malformed_json}
        end

      {:error, _reason} ->
        {:error, :read_body_error}
    end
  end

  defp bad_request(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{error: message, status: "error"}))
    |> halt()
  end

  defp server_error(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(500, Jason.encode!(%{error: message, status: "error"}))
    |> halt()
  end

  defp dispatch_signal(signal, handler) do
    try do
      result =
        cond do
          is_function(handler, 1) ->
            handler.(signal)

          is_pid(handler) ->
            send(handler, {:telegram_update, signal})
            :ok

          is_atom(handler) and handler != nil ->
            cond do
              Code.ensure_loaded?(handler) and function_exported?(handler, :handle_signal, 1) ->
                handler.handle_signal(signal)

              Code.ensure_loaded?(handler) and function_exported?(handler, :handle_update, 1) ->
                handler.handle_update(signal)

              true ->
                :ok
            end

          true ->
            :ok
        end

      case result do
        {:error, reason} ->
          Logger.error("Webhook handler returned error: #{inspect(reason)}")
          {:error, reason}

        :error ->
          Logger.error("Webhook handler returned :error")
          {:error, :handler_error}

        _ ->
          :ok
      end
    rescue
      e ->
        Logger.error("Webhook handler error: #{inspect(e)}")
        {:error, {:handler_exception, e}}
    catch
      :throw, value ->
        Logger.error("Webhook handler threw: #{inspect(value)}")
        {:error, {:handler_throw, value}}

      :exit, reason ->
        Logger.error("Webhook handler exited: #{inspect(reason)}")
        {:error, {:handler_exit, reason}}

      kind, reason ->
        Logger.error("Webhook handler #{kind}: #{inspect(reason)}")
        {:error, {:handler_crash, {kind, reason}}}
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized", status: "error"}))
    |> halt()
  end

  defp fetch_config_secret_token do
    try do
      case Lux.Config.telegram_secret_token() do
        token when is_binary(token) -> token
        _ -> System.get_env("TELEGRAM_SECRET_TOKEN")
      end
    rescue
      _ -> System.get_env("TELEGRAM_SECRET_TOKEN")
    catch
      _ -> System.get_env("TELEGRAM_SECRET_TOKEN")
    end
  end
end

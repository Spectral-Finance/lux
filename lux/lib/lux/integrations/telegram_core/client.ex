defmodule Lux.Integrations.TelegramCore.Client do
  @moduledoc """
  Advanced client for Telegram Core API (MTProto) via Python bridge.
  Provides access to user-level actions not available in Bot API.
  """

  require Logger

  @type request_opts :: %{
    optional(:session_name) => String.t(),
    optional(:api_id) => integer(),
    optional(:api_hash) => String.t(),
    optional(:chat_id) => String.t(),
    optional(:text) => String.t(),
    optional(:limit) => integer()
  }

  @doc """
  Sends a message using a user account via MTProto.
  """
  @spec send_message(request_opts()) :: {:ok, String.t()} | {:error, term()}
  def send_message(opts \\ %{}) do
    # Extract credentials from config if not provided
    session = opts[:session_name] || Lux.Config.telegram_core_session()
    api_id = opts[:api_id] || Lux.Config.telegram_core_api_id()
    api_hash = opts[:api_hash] || Lux.Config.telegram_core_api_hash()
    chat_id = opts[:chat_id]
    text = opts[:text]

    if is_nil(chat_id) or is_nil(text) do
      {:error, :missing_params}
    else
      # Call the Python bridge
      case Lux.Python.eval("lux.telegram_core.run_send_message", [session, api_id, api_hash, chat_id, text]) do
        {:ok, %{"status" => "ok", "message_id" => mid}} -> {:ok, mid}
        {:ok, %{"status" => "error", "message" => msg}} -> {:error, msg}
        error -> {:error, error}
      end
    end
  end

  @doc """
  Fetches message history from a chat.
  """
  @spec get_messages(request_opts()) :: {:ok, list()} | {:error, term()}
  def get_messages(opts \\ %{}) do
    session = opts[:session_name] || Lux.Config.telegram_core_session()
    api_id = opts[:api_id] || Lux.Config.telegram_core_api_id()
    api_hash = opts[:api_hash] || Lux.Config.telegram_core_api_hash()
    chat_id = opts[:chat_id]
    limit = opts[:limit] || 10

    if is_nil(chat_id) do
      {:error, :missing_chat_id}
    else
      case Lux.Python.eval("lux.telegram_core.run_get_messages", [session, api_id, api_hash, chat_id, limit]) do
        {:ok, %{"status" => "ok", "messages" => msgs}} -> {:ok, msgs}
        {:ok, %{"status" => "error", "message" => msg}} -> {:error, msg}
        error -> {:error, error}
      end
    end
  end
end

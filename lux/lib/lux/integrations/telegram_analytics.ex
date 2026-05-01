defmodule Lux.Integrations.TelegramAnalytics do
  @moduledoc """
  Common settings and functions for Telegram Bot API analytics integration.

  Provides authentication, request configuration, and shared utilities
  for all Telegram analytics-related lenses and prisms.
  """

  @base_url "https://api.telegram.org/bot"

  @doc """
  Returns the base URL for Telegram Bot API endpoints.
  """
  def base_url, do: "#{@base_url}#{bot_token()}"

  @doc """
  Retrieves the Telegram Bot token from application config.
  """
  def bot_token, do: Lux.Config.telegram_bot_token()

  @doc """
  Common headers for Telegram API calls.
  """
  def headers do
    [{"Content-Type", "application/json"}]
  end

  @doc """
  Parses Telegram API error responses.
  """
  def parse_error(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def parse_error(%{"ok" => false, "error_code" => code, "description" => description}) do
    {:error, "Telegram API error #{code}: #{description}"}
  end

  def parse_error(error), do: {:error, inspect(error)}

  @doc """
  Validates a Telegram chat ID.
  """
  def validate_chat_id(id) when is_integer(id), do: {:ok, id}
  def validate_chat_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid chat ID format"}
    end
  end
  def validate_chat_id(_), do: {:error, "Chat ID must be an integer or numeric string"}

  @doc """
  Validates a date string in ISO 8601 format (YYYY-MM-DD).
  """
  def validate_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, _} -> {:ok, date}
      {:error, _} -> {:error, "Invalid date format. Expected YYYY-MM-DD"}
    end
  end

  def validate_date(_), do: {:error, "Date must be a string in YYYY-MM-DD format"}
end

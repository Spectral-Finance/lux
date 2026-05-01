defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter/X API v2 integration.

  Provides authentication, request configuration, and shared utilities
  for all Twitter-related lenses and prisms.
  """

  @base_url "https://api.twitter.com/2"
  @base_url_v1 "https://api.twitter.com/1.1"

  @doc """
  Returns the base URL for Twitter API v2 endpoints.
  """
  def base_url, do: @base_url

  @doc """
  Returns the base URL for Twitter API v1.1 endpoints.
  """
  def base_url_v1, do: @base_url_v1

  @doc """
  Common request settings for Twitter API calls.
  Uses Bearer token authentication for API v2.
  """
  def request_settings do
    %{
      headers: [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{bearer_token()}"}
      ],
      auth: %{
        type: :api_key,
        key: fn -> bearer_token() end
      }
    }
  end

  @doc """
  Common headers for Twitter API v2 calls.
  """
  def headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{bearer_token()}"}
    ]
  end

  @doc """
  Common auth settings for Twitter API calls.
  """
  def auth do
    %{
      type: :api_key,
      key: fn -> bearer_token() end
    }
  end

  @doc """
  Retrieves the Twitter Bearer token from application config.
  """
  def bearer_token, do: Lux.Config.twitter_bearer_token()

  @doc """
  Parses Twitter API error responses into a consistent format.
  """
  def parse_error(%{"errors" => errors}) when is_list(errors) do
    messages = Enum.map(errors, fn e -> e["message"] end)
    {:error, Enum.join(messages, "; ")}
  end

  def parse_error(%{"error" => error}) when is_binary(error) do
    {:error, error}
  end

  def parse_error(%{"title" => title, "detail" => detail}) do
    {:error, "#{title}: #{detail}"}
  end

  def parse_error(error), do: {:error, inspect(error)}

  @doc """
  Validates a Twitter user ID or username.
  """
  def validate_user_identifier(id) when is_integer(id), do: {:ok, Integer.to_string(id)}
  def validate_user_identifier(id) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}
  def validate_user_identifier(_), do: {:error, "Invalid user identifier"}

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

  @doc """
  Validates a granularity parameter for time series queries.
  """
  def validate_granularity(granularity) when granularity in ~w(minute hour day) do
    {:ok, granularity}
  end

  def validate_granularity(_), do: {:error, "Granularity must be one of: minute, hour, day"}
end

defmodule Lux.Lenses.Twitter.Base do
  @moduledoc """
  Base module for Twitter API lenses providing common HTTP request functionality using Req.
  """

  @base_url "https://api.twitter.com/2"

  @doc """
  Returns a pre-configured Req request struct for Twitter API v2.
  """
  def client do
    bearer_token = Lux.Config.twitter_bearer_token()

    Req.new(
      base_url: @base_url,
      auth: {:bearer, bearer_token},
      headers: [{"Accept", "application/json"}]
    )
  end

  @doc """
  Processes a generic Req response from Twitter.
  """
  def process_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  def process_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, "Twitter API error (status #{status}): #{inspect(body)}"}
  end

  def process_response({:error, reason}) do
    {:error, "Request failed: #{inspect(reason)}"}
  end
end

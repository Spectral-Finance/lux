defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Twitter client module with OAuth2 bearer token auth and API v2 endpoints for tweets, DMs, follows, search.
  """

  require HTTPoison
  require OAuth2

  defstruct [:base_url, :access_token]

  @doc """
  Creates a new Twitter client instance.

  ## Examples

      iex> Lux.Integrations.Twitter.Client.new("https://api.twitter.com/2", "your_access_token")
      %Lux.Integrations.Twitter.Client{base_url: "https://api.twitter.com/2", access_token: "your_access_token"}
  """
  def new(base_url, access_token) do
    %__MODULE__{base_url: base_url, access_token: access_token}
  end

  @doc """
  Fetches tweets from the Twitter API.

  ## Examples

      iex> client = Lux.Integrations.Twitter.Client.new("https://api.twitter.com/2", "your_access_token")
      iex> Lux.Integrations.Twitter.Client.fetch_tweets(client, "user_id")
      {:ok, %HTTPoison.Response{}}
  """
  def fetch_tweets(%__MODULE__{base_url: base_url, access_token: access_token}, user_id) do
    url = "#{base_url}/users/#{user_id}/tweets"
    headers = [{"Authorization", "Bearer #{access_token}"}]
    HTTPoison.get(url, headers)
  end

  @doc """
  Sends a direct message to a Twitter user.

  ## Examples

      iex> client = Lux.Integrations.Twitter.Client.new("https://api.twitter.com/2", "your_access_token")
      iex> Lux.Integrations.Twitter.Client.send_dm(client, "user_id", "message")
      {:ok, %HTTPoison.Response{}}
  """
  def send_dm(%__MODULE__{base_url: base_url, access_token: access_token}, user_id, message) do
    url = "#{base_url}/users/#{user_id}/messages"
    headers = [{"Authorization", "Bearer #{access_token}"}]
    body = Jason.encode!(%{"text" => message})
    HTTPoison.post(url, body, headers)
  end

  @doc """
  Follows a Twitter user.

  ## Examples

      iex> client = Lux.Integrations.Twitter.Client.new("https://api.twitter.com/2", "your_access_token")
      iex> Lux.Integrations.Twitter.Client.follow_user(client, "user_id")
      {:ok, %HTTPoison.Response{}}
  """
  def follow_user(%__MODULE__{base_url: base_url, access_token: access_token}, user_id) do
    url = "#{base_url}/users/#{user_id}/following"
    headers = [{"Authorization", "Bearer #{access_token}"}]
    HTTPoison.post(url, "", headers)
  end

  @doc """
  Searches for tweets using the Twitter API.

  ## Examples

      iex> client = Lux.Integrations.Twitter.Client.new("https://api.twitter.com/2", "your_access_token")
      iex> Lux.Integrations.Twitter.Client.search_tweets(client, "query")
      {:ok, %HTTPoison.Response{}}
  """
  def search_tweets(%__MODULE__{base_url: base_url, access_token: access_token}, query) do
    url = "#{base_url}/search/recent"
    headers = [{"Authorization", "Bearer #{access_token}"}]
    params = [query: query]
    HTTPoison.get(url, headers, params: params)
  end
end
defmodule Lux.Perplexity.Client do
  @moduledoc """
  Perplexity AI client for Lux framework.
  
  This module provides integration with Perplexity AI API for advanced language
  model capabilities and specialized knowledge tasks.
  """

  alias Lux.Perplexity.HTTPClient

  @perplexity_api_url "https://api.perplexity.ai"

  @doc """
  Create a new Perplexity AI client with the given API key.
  """
  def new(api_key) do
    %HTTPClient{api_key: api_key}
  end

  @doc """
  Send a chat completion request to Perplexity AI.
  """
  def chat_completion(client, messages, options \\ []) do
    HTTPClient.request(client, :post, "/chat/completions", %{
      model: Keyword.get(options, :model, "llama-3"),
      messages: messages
    })
  end

  @doc """
  Stream a chat completion response from Perplexity AI.
  """
  def stream_chat_completion(client, messages, options \\ []) do
    model = Keyword.get(options, :model, "llama-3")
    url = @perplexity_api_url <> "/chat/completions"
    
    case HTTPClient.stream_request(client, :post, url, %{
      model: model,
      messages: messages,
      stream: true
    }) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Handle Perplexity AI API errors and provide meaningful error responses.
  """
  def handle_error(error) do
    case error do
      {:error, %{status: 401}} -> 
        {:error, "Invalid API key or authentication failed"}
      {:error, %{status: 429}} -> 
        {:error, "Rate limit exceeded"}
      {:error, %{status: 500}} -> 
        {:error, "Internal server error"}
      _ -> error
    end
  end
end

defmodule Lux.Perplexity.HTTPClient do
  @moduledoc """
  HTTP client for Perplexity AI API.
  """

  defstruct [:api_key, :base_url, :http_client]

  def new(api_key, base_url \\ "https://api.perplexity.ai") do
    %__MODULE__{
      api_key: api_key,
      base_url: base_url,
      http_client: HTTPoison
    }
  end

  def request(client, method, path, body) do
    url = client.base_url <> path
    headers = [
      {"Authorization", "Bearer #{client.api_key}"},
      {"Content-Type", "application/json"}
    ]

    case client.http_client.request(method, url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}
      {:error, reason} ->
        Lux.Perplexity.Client.handle_error({:error, reason})
    end
  end

  def stream_request(client, method, path, body) do
    url = client.base_url <> path
    headers = [
      {"Authorization", "Bearer #{client.api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "text/event-stream"}
    ]

    client.http_client.request(method, url, body, headers)
  end
end
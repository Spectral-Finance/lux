defmodule Lux.PerplexityAI do
+defmodule Lux.PerplexityAI do
  @moduledoc """
  Perplexity AI client for Lux - Elixir implementation
  """

  alias Lux.PerplexityAI

  @doc """
  Initialize the Perplexity AI client with the given API key and configuration.
  """
  def client(api_key, opts \\ []) do
    %PerplexityAI{api_key: api_key, opts: opts}
  end

  @doc """
  Make a streaming request to Perplexity AI
  """
  def stream_request(client, prompt) do
    # Implementation would go here
    # This is a simplified example
    :ok
  end
end

  @doc """
  Another streaming function example
  """
  def stream_another() do
    # Another function implementation
  end
end
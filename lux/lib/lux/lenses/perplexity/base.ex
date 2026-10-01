defmodule Lux.Lenses.Perplexity.Base do
  @moduledoc """
  Base module for Perplexity AI Lenses.
  Provides shared functionality like configuration, authentication, and error handling.
  """

  @doc """
  Returns the base URL for the Perplexity API.
  """
  def base_url, do: "https://api.perplexity.ai"

  @doc """
  Injects the Perplexity API key into the headers for a Lens.
  """
  def add_api_key(lens) do
    auth_header = {"authorization", "Bearer #{Lux.Config.perplexity_api_key()}"}
    accept_header = {"accept", "application/json"}
    
    %{lens | headers: lens.headers ++ [auth_header, accept_header]}
  end

  @doc """
  Common error handling for Perplexity API responses.
  """
  def handle_response(%{"error" => error}) when is_map(error) do
    message = error["message"] || "Unknown Perplexity API error"
    {:error, message}
  end

  def handle_response(%{"error" => error}) when is_binary(error) do
    {:error, error}
  end

  def handle_response(response) do
    {:ok, response}
  end
end

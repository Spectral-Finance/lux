defmodule Lux.Lenses.Telegram.Client do
  @moduledoc """
  Client for making Telegram Bot API requests with rate limiting and error handling.

  This module provides a robust client for making requests to the Telegram Bot API,
  with built-in rate limiting and error handling.
  """

  alias Lux.Lenses.Telegram.RateLimiter
  alias Lux.Lenses.Telegram.ErrorHandler
  require Logger

  @doc """
  Makes a request to the Telegram Bot API with rate limiting and error handling.

  ## Parameters

  - `lens`: The Lens struct for the Telegram Bot API
  - `params`: The parameters for the API request
  - `opts`: Options for the request
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)
    - `skip_rate_limit`: Skip rate limiting (default: false)
    - `skip_retries`: Skip retry logic (default: false)

  ## Returns

  Returns the result of the API request or an error.
  """
  def request(lens, params, opts \\ []) do
    method = Map.get(params, "method") || Map.get(params, :method)
    skip_rate_limit = Keyword.get(opts, :skip_rate_limit, false)
    skip_retries = Keyword.get(opts, :skip_retries, false)

    Logger.debug("Making Telegram API request: #{inspect(method)}")

    # Apply rate limiting and retries based on options
    cond do
      skip_rate_limit && skip_retries ->
        # Skip both rate limiting and retries
        make_request(lens, params)

      skip_rate_limit ->
        # Skip rate limiting but use retries
        ErrorHandler.with_retries(
          fn -> make_request(lens, params) end,
          opts
        )

      skip_retries ->
        # Use rate limiting but skip retries
        RateLimiter.with_rate_limit(params, fn ->
          make_request(lens, params)
        end)

      true ->
        # Use both rate limiting and retries (default)
        RateLimiter.with_rate_limit(params, fn ->
          ErrorHandler.with_retries(
            fn -> make_request(lens, params) end,
            opts
          )
        end)
    end
  end

  @doc """
  Makes a request to the Telegram Bot API without rate limiting or error handling.

  This is mainly used internally by the request/3 function.
  """
  def make_request(lens, params) do
    start_time = System.monotonic_time(:millisecond)

    [url: lens.url, headers: lens.headers, max_retries: 0]
    |> Keyword.merge(Application.get_env(:lux, :req_options, []))
    |> Req.new()
    |> Req.request([method: lens.method] ++ body_or_params(lens.method, params))
    |> case do
      {:ok, %{status: 200, body: body}} ->
        end_time = System.monotonic_time(:millisecond)
        method = Map.get(params, "method") || Map.get(params, :method)
        Logger.debug("Telegram API request succeeded: #{inspect(method)} (#{end_time - start_time}ms)")
        process_response(body)

      {:ok, %{status: status, body: body}} ->
        end_time = System.monotonic_time(:millisecond)
        method = Map.get(params, "method") || Map.get(params, :method)
        Logger.warn("Telegram API request failed with status #{status}: #{inspect(method)} (#{end_time - start_time}ms)")
        {:error, body}

      {:error, %Req.TransportError{reason: reason}} ->
        end_time = System.monotonic_time(:millisecond)
        method = Map.get(params, "method") || Map.get(params, :method)
        Logger.warn("Telegram API transport error: #{inspect(method)} - #{inspect(reason)} (#{end_time - start_time}ms)")
        {:error, inspect(reason)}

      {:error, error} ->
        end_time = System.monotonic_time(:millisecond)
        method = Map.get(params, "method") || Map.get(params, :method)
        Logger.warn("Telegram API error: #{inspect(method)} - #{inspect(error)} (#{end_time - start_time}ms)")
        {:error, inspect(error)}
    end
  end

  # Helper functions

  @doc """
  Processes a response from the Telegram Bot API.

  ## Parameters

  - `response`: The response body from the Telegram Bot API

  ## Returns

  - `{:ok, result}` if the response was successful
  - `{:error, error}` if the response was an error
  """
  def process_response(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def process_response(%{"ok" => false, "description" => error}) do
    {:error, error}
  end

  def process_response(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  @doc """
  Formats parameters for the HTTP request based on the HTTP method.

  ## Parameters

  - `method`: The HTTP method (:get, :post, etc.)
  - `params`: The parameters for the request

  ## Returns

  - `[params: params]` for GET requests
  - `[json: params]` for non-GET requests
  """
  def body_or_params(:get, params), do: [params: params]
  def body_or_params(_method, params), do: [json: params]

  @doc """
  Makes a request to the Telegram Bot API with custom options.

  This is a convenience function that allows you to customize the request options.

  ## Parameters

  - `lens`: The Lens struct for the Telegram Bot API
  - `params`: The parameters for the API request
  - `opts`: Options for the request (see request/3)

  ## Returns

  Returns the result of the API request or an error.
  """
  def request_with_options(lens, params, opts) do
    request(lens, params, opts)
  end

  @doc """
  Makes a request to the Telegram Bot API without rate limiting.

  This is useful for methods that don't need rate limiting, such as getMe.

  ## Parameters

  - `lens`: The Lens struct for the Telegram Bot API
  - `params`: The parameters for the API request
  - `opts`: Options for the request (see request/3)

  ## Returns

  Returns the result of the API request or an error.
  """
  def request_without_rate_limit(lens, params, opts \\ []) do
    request(lens, params, Keyword.put(opts, :skip_rate_limit, true))
  end

  @doc """
  Makes a request to the Telegram Bot API without retries.

  This is useful for methods where retrying doesn't make sense, such as deleteMessage.

  ## Parameters

  - `lens`: The Lens struct for the Telegram Bot API
  - `params`: The parameters for the API request
  - `opts`: Options for the request (see request/3)

  ## Returns

  Returns the result of the API request or an error.
  """
  def request_without_retries(lens, params, opts \\ []) do
    request(lens, params, Keyword.put(opts, :skip_retries, true))
  end

  @doc """
  Makes a direct request to the Telegram Bot API without rate limiting or retries.

  This is useful for methods that need to be executed immediately without any overhead.

  ## Parameters

  - `lens`: The Lens struct for the Telegram Bot API
  - `params`: The parameters for the API request
  - `opts`: Options for the request (see request/3)

  ## Returns

  Returns the result of the API request or an error.
  """
  def request_direct(lens, params, opts \\ []) do
    request(lens, params, Keyword.merge(opts, [skip_rate_limit: true, skip_retries: true]))
  end
end

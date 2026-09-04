defmodule Lux.Telegram.Middleware.Retry do
  @moduledoc """
  Req middleware for Telegram Bot API retries with exponential backoff.
  Retries on transport errors and HTTP status 5xx responses across request, response, and error steps.
  """

  @doc """
  Attaches retry middleware to a Req request struct.
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    opts_list = if is_map(opts), do: Map.to_list(opts), else: opts || []

    filtered_opts =
      Keyword.take(opts_list, [
        :max_retries,
        :base_backoff,
        :max_backoff,
        :backoff_factor,
        :sleep_fun
      ])

    req
    |> Req.Request.register_options([
      :max_retries,
      :base_backoff,
      :max_backoff,
      :backoff_factor,
      :sleep_fun
    ])
    |> Req.Request.merge_options(filtered_opts)
    |> Req.Request.append_request_steps(telegram_wrap_adapter: &wrap_adapter/1)
    |> Req.Request.append_response_steps(telegram_retry: &handle/1)
    |> Req.Request.append_error_steps(telegram_retry: &handle/1)
  end

  @doc """
  Request step that wraps the adapter to catch synchronous exceptions
  and return `{request, exception}` tuples for error_steps processing.
  """
  def wrap_adapter(%Req.Request{} = req) do
    adapter = req.adapter

    wrapped_adapter = fn request ->
      try do
        case adapter do
          fun when is_function(fun, 1) ->
            fun.(request)

          {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
            apply(mod, fun, [request | args])

          other ->
            raise "expected adapter to be 1-arity function or MFA, got: #{inspect(other)}"
        end
      rescue
        exception ->
          {request, exception}
      catch
        kind, reason ->
          {request, %Req.TransportError{reason: {kind, reason}}}
      end
    end

    %{req | adapter: wrapped_adapter}
  end

  @doc """
  Handles response and error steps for transport errors and HTTP 5xx responses.
  """
  def handle({request, response_or_exception}) do
    if retryable?(response_or_exception) do
      retry_count = Req.Request.get_private(request, :telegram_retry_count, 0)
      max_retries = Req.Request.get_option(request, :max_retries, 3)

      if retry_count < max_retries do
        base_backoff = Req.Request.get_option(request, :base_backoff, 100)
        max_backoff = Req.Request.get_option(request, :max_backoff, 5000)
        factor = Req.Request.get_option(request, :backoff_factor, 2)
        sleep_fun = Req.Request.get_option(request, :sleep_fun, fn ms -> Process.sleep(ms) end)

        delay = calculate_backoff(base_backoff, factor, retry_count, max_backoff)
        sleep_fun.(delay)

        request = Req.Request.put_private(request, :telegram_retry_count, retry_count + 1)
        {request, new_response_or_exception} = Req.Request.run_request(%{request | halted: false})
        Req.Request.halt(request, new_response_or_exception)
      else
        {request, response_or_exception}
      end
    else
      {request, response_or_exception}
    end
  end

  @doc """
  Determines if a response or exception should be retried.
  """
  def retryable?(%Req.Response{status: status}) when status in 500..599, do: true
  def retryable?(%Req.Response{}), do: false
  def retryable?(%Req.TransportError{}), do: true
  def retryable?(%{__exception__: true}), do: true
  def retryable?({:error, %Req.TransportError{}}), do: true
  def retryable?({:error, %{__exception__: true}}), do: true
  def retryable?({:error, reason}) when is_atom(reason) and reason in [:econnrefused, :timeout, :closed, :nxdomain], do: true
  def retryable?(_), do: false

  @doc """
  Calculates exponential backoff delay in milliseconds.
  """
  def calculate_backoff(base_backoff, factor, retry_count, max_backoff) do
    base = if is_number(base_backoff) and base_backoff >= 0, do: base_backoff, else: 100
    fact = if is_number(factor) and factor >= 1, do: factor, else: 2
    count = if is_integer(retry_count) and retry_count >= 0, do: retry_count, else: 0
    max_b = if is_number(max_backoff) and max_backoff >= 0, do: max_backoff, else: 5000

    delay = trunc(base * :math.pow(fact, count))
    min(delay, trunc(max_b))
  end
end

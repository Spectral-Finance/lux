defmodule Lux.LLM.Ollama do
  @moduledoc """
  Local LLM integration backed by [Ollama](https://ollama.com/). It mirrors the
  behaviour expected from other `Lux.LLM` implementations while adding model
  lifecycle management, simple resource limiting and telemetry hooks.
  """

  @behaviour Lux.LLM

  alias Lux.Config, as: LuxConfig
  alias Lux.LLM.Ollama.{Client, ModelManager, ResourcePool}
  alias Lux.LLM.ResponseSignal

  require Logger

  defmodule Config do
    @moduledoc "Configuration options for the Ollama client."

    @default_model_ttl :timer.minutes(30)
    @default_cleanup_interval :timer.minutes(10)
    @default_max_concurrency 2

    @type t :: %__MODULE__{
            endpoint: String.t() | {:runtime_config, atom(), list(), any()},
            model: String.t(),
            keep_alive: String.t() | integer() | nil,
            options: map(),
            stream: boolean(),
            format: String.t() | nil,
            messages: [map()],
            auto_pull: boolean(),
            model_ttl: non_neg_integer(),
            cleanup_interval: non_neg_integer(),
            max_concurrency: pos_integer(),
            request_timeout: non_neg_integer(),
            pull_timeout: non_neg_integer() | nil,
            telemetry_metadata: map()
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3",
              keep_alive: "5m",
              options: %{},
              stream: false,
              format: "json",
              messages: [],
              auto_pull: true,
              model_ttl: @default_model_ttl,
              cleanup_interval: @default_cleanup_interval,
              max_concurrency: @default_max_concurrency,
              request_timeout: 30_000,
              pull_timeout: nil,
              telemetry_metadata: %{}

    def defaults do
      %{
        model_ttl: @default_model_ttl,
        cleanup_interval: @default_cleanup_interval,
        max_concurrency: @default_max_concurrency
      }
    end
  end

  @impl true
  def call(prompt, tools, opts) do
    config = build_config(opts)

    with :ok <- ModelManager.ensure_model(config),
         :ok <- ensure_permit(config.max_concurrency, config.telemetry_metadata) do
      try do
        case execute_request(prompt, tools, config) do
          {:ok, _} = ok ->
            ModelManager.touch(config.model)
            ok

          {:error, _} = error ->
            error
        end
      after
        release_permit()
      end
    else
      {:error, _} = error -> error
    end
  end

  # -- Helpers ---------------------------------------------------------------------

  defp execute_request(prompt, tools, config) do
    body = build_body(prompt, tools, config)

    metadata =
      config.telemetry_metadata
      |> Map.put(:model, config.model)
      |> Map.put_new(:endpoint, resolve(config.endpoint))

    :telemetry.span([:lux, :ollama, :request], metadata, fn ->
      case Client.chat(config, body) do
        {:ok, %{status: 200, body: response}} ->
          measurements = %{status: :ok}
          {measurements, build_response(response, config)}

        {:ok, %{status: status, body: body}} ->
          measurements = %{status: :error, http_status: status}
          {measurements, {:error, {status, body}}}

        {:error, reason} ->
          measurements = %{status: :error, error: reason}
          {measurements, {:error, reason}}
      end
    end)
    |> case do
      {_measurements, response} -> response
    end
  end

  defp build_body(prompt, tools, config) do
    messages =
      config.messages ++
        [%{
            role: "user",
            content: prompt <> tool_prompt_suffix(tools)
          }]

    base = %{
      model: resolve(config.model),
      messages: messages,
      stream: config.stream,
      options: build_options(config)
    }

    base
    |> maybe_put(:format, config.format)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp build_options(%Config{keep_alive: nil, options: options}), do: options

  defp build_options(%Config{keep_alive: keep_alive, options: options}) do
    options
    |> Map.new()
    |> Map.put_new(:keep_alive, keep_alive)
  end

  defp tool_prompt_suffix(_tools), do: ""

  defp build_response(%{"message" => %{"content" => content}} = body, config) do
    with {:ok, parsed} <- maybe_decode(content, config.format) do
      signal =
        %{
          schema_id: ResponseSignal,
          payload: %{
            content: parsed,
            model: body["model"] || config.model,
            finish_reason: finish_reason(body),
            tool_calls: nil,
            tool_calls_results: nil
          },
          metadata: build_metadata(body),
          sender: nil,
          recipient: nil,
          timestamp: DateTime.utc_now()
        }
        |> Lux.Signal.new()

      ResponseSignal.validate(signal)
    end
  end

  defp build_response(body, _config) do
    {:error, {:unexpected_response, body}}
  end

  defp maybe_decode(content, "json") when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"raw" => content}}
    end
  end

  defp maybe_decode(content, _), do: {:ok, content}

  defp finish_reason(%{"done_reason" => reason}) when is_binary(reason), do: reason
  defp finish_reason(%{"done" => true}), do: "stop"
  defp finish_reason(_body), do: "unknown"

  defp build_metadata(body) do
    %{
      created: body["created_at"],
      total_duration: body["total_duration"],
      load_duration: body["load_duration"],
      eval_count: body["eval_count"],
      input_tokens: get_in(body, ["metrics", "input_tokens"]),
      output_tokens: get_in(body, ["metrics", "output_tokens"])
    }
  end

  defp ensure_permit(_limit, _meta) do
    case ResourcePool.checkout() do
      :ok -> :ok
      {:error, :timeout} -> {:error, :busy}
    end
  end

  defp release_permit, do: ResourcePool.checkin()

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp resolve(%Config{} = config), do: config
  defp resolve({:runtime_config, _, _, _} = runtime), do: LuxConfig.resolve(runtime)
  defp resolve(value), do: value

  defp build_config(opts) do
    defaults = Config.defaults()

    env_config =
      :lux
      |> Application.get_env(__MODULE__, [])
      |> Map.new(fn {k, v} -> {k, resolve(v)} end)

    opts = opts |> Map.new(fn {k, v} -> {k, resolve(v)} end)

    defaults
    |> Map.merge(env_config)
    |> Map.merge(opts)
    |> then(&struct(Config, &1))
  end

  @doc false
  def defaults, do: Config.defaults()

  def default(type), do: defaults()[type]
end

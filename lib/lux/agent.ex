defmodule Lux.Agent do
  @moduledoc """
  A Agent defines an autonomous agent's capabilities, behaviors and goals.
  The actual execution and supervision is handled by the Lux runtime.
  """

  alias Lux.LLM
  alias Lux.LLM.OpenAI.Config

  @type scheduled_beam :: {module(), String.t(), keyword()}
  @type collaboration_protocol :: :ask | :tell | :delegate | :request_review
  @type memory_config :: %{
          backend: module(),
          name: atom() | nil
        }

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          goal: String.t(),
          module: module(),
          prisms: [Lux.Prism.t()],
          beams: [Lux.Beam.t()],
          lenses: [Lux.Lens.t()],
          accepts_signals: [Lux.SignalSchema.t()],
          llm_config: map(),
          memory_config: memory_config() | nil,
          memory_pid: pid() | nil
        }

  defstruct id: nil,
            name: "",
            description: "",
            goal: "",
            module: nil,
            prisms: [],
            beams: [],
            lenses: [],
            accepts_signals: [],
            memory_config: nil,
            memory_pid: nil,
            llm_config: %{
              provider: :openai,
              model: "gpt-4",
              temperature: 0.7
              # max_tokens: 1000
            }

  @callback chat(t(), message :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback handle_signal(t(), Lux.Signal.t()) :: {:ok, term()} | :ignore | {:error, term()}

  @callback new(attrs :: map()) :: t()

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Lux.Agent

      use GenServer

      @default_values %{
        module: __MODULE__
      }

      @impl Lux.Agent
      def new(attrs) do
        @default_values
        |> Map.merge(attrs)
        |> Lux.Agent.new()
      end

      @impl Lux.Agent
      def chat(agent, message, opts \\ []) do
        Lux.Agent.chat(agent, message, opts)
      end

      @impl Lux.Agent
      def handle_signal(agent, signal) do
        :ignore
      end

      # GenServer Client API
      def start_link(attrs \\ %{}) do
        agent = new(attrs)

        GenServer.start_link(__MODULE__, agent, name: get_name(agent))
      end

      def child_spec(opts) do
        %{
          id: {__MODULE__, opts[:name] || :default},
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 60_000
        }
      end

      defp get_name(%{name: name}) when is_binary(name), do: String.to_atom(name)
      defp get_name(%{name: nil}), do: __MODULE__
      defp get_name(%{name: name}) when is_atom(name), do: name

      def send_message(pid, message, opts \\ []) do
        timeout = opts[:timeout] || 120_000
        GenServer.call(pid, {:chat, message, opts}, timeout)
      end

      # GenServer Callbacks
      @impl GenServer
      def init(agent) do
        # Initialize memory if configured
        agent =
          case agent.memory_config do
            %{backend: backend} = config when not is_nil(backend) ->
              {:ok, pid} = backend.initialize(name: config[:name])
              %{agent | memory_pid: pid}

            _ ->
              agent
          end

        {:ok, agent}
      end

      @impl GenServer
      def handle_call({:chat, message, opts}, _from, agent) do
        case chat(agent, message, opts) do
          {:ok, response} = ok -> {:reply, ok, agent}
          {:error, _reason} = error -> {:reply, error, agent}
        end
      end

      @impl GenServer
      def handle_info({:signal, signal}, agent) do
        _ = handle_signal(agent, signal)
        {:noreply, agent}
      end

      @impl GenServer
      def terminate(_reason, agent) do
        # Cleanup memory if it exists
        if agent.memory_pid do
          Process.exit(agent.memory_pid, :normal)
        end

        :ok
      end

      defoverridable new: 1, chat: 3, handle_signal: 2
    end
  end

  @doc """
  Creates a new agent from the given attributes
  """
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, %{
      id: Map.get(attrs, :id, Lux.UUID.generate()),
      name: Map.get(attrs, :name, "Anonymous Agent"),
      description: Map.get(attrs, :description, ""),
      goal: Map.get(attrs, :goal, ""),
      module: Map.get(attrs, :module, __MODULE__),
      memory_config: Map.get(attrs, :memory_config),
      memory_pid: nil,
      llm_config:
        attrs
        |> Map.get(:llm_config, %{})
        |> then(fn
          %Config{} = config -> config
          config -> struct(Config, config)
        end),
      prisms: Map.get(attrs, :prisms, []),
      beams: Map.get(attrs, :beams, []),
      lenses: Map.get(attrs, :lenses, []),
      accepts_signals: Map.get(attrs, :accepts_signals, [])
    })
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  def handle_signal(agent, signal) do
    apply(agent.module, :handle_signal, [agent, signal])
  end

  def chat(agent, message, opts) do
    llm_config = build_llm_config(agent, opts)

    case LLM.call(message, agent.beams ++ agent.prisms, llm_config) do
      {:ok, %{payload: %{content: content}}} when is_map(content) ->
        store_interaction(agent, message, format_content(content), opts)
        {:ok, format_content(content)}

      {:ok, %{payload: %{content: content}}} when is_binary(content) ->
        store_interaction(agent, message, content, opts)
        {:ok, content}

      {:error, reason} ->
        {:error, reason}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error["message"] || "Unknown error"}

      {:ok, %Lux.Signal{payload: %{tool_calls_results: tool_call_results}} = signal} ->
        store_interaction(agent, message, format_content(tool_call_results), opts)
        {:ok, signal}

      unexpected ->
        {:error, {:unexpected_response, unexpected}}
    end
  end

  # Private function to build LLM config with memory context if enabled
  defp build_llm_config(agent, opts) do
    if agent.memory_pid && Keyword.get(opts, :use_memory, false) do
      max_context = Keyword.get(opts, :max_memory_context, 5)
      {:ok, recent} = agent.memory_config.backend.recent(agent.memory_pid, max_context)

      # Convert memory entries to chat messages
      memory_messages =
        recent
        |> Enum.reverse()
        |> Enum.map(fn entry ->
          %{role: entry.metadata.role, content: entry.content}
        end)

      # Add memory context to existing messages or create new messages list
      Map.update(agent.llm_config, :messages, memory_messages, fn existing ->
        memory_messages ++ existing
      end)
    else
      agent.llm_config
    end
  end

  # Private function to store interactions in memory if enabled
  defp store_interaction(agent, user_message, assistant_response, opts) do
    if agent.memory_pid && Keyword.get(opts, :use_memory, false) do
      {:ok, _} =
        agent.memory_config.backend.add(
          agent.memory_pid,
          user_message,
          :interaction,
          %{role: :user}
        )

      {:ok, _} =
        agent.memory_config.backend.add(
          agent.memory_pid,
          assistant_response,
          :interaction,
          %{role: :assistant}
        )
    end
  end

  # Helper function to format map content into a readable string
  defp format_content(content) when is_map(content) do
    Enum.map_join(content, "\n", fn {k, v} -> "#{k}: #{format_value(v)}" end)
  end

  defp format_content(result) when is_list(result) do
    Enum.map_join(result, "\n", fn element -> format_content(element) end)
  end

  defp format_value(value) when is_list(value) do
    Enum.map_join(value, ", ", &format_value/1)
  end

  defp format_value(value) when is_map(value), do: format_content(value)
  defp format_value(value), do: to_string(value)
end

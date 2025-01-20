defmodule Lux.Specter do
  @moduledoc """
  A Specter defines an autonomous agent's capabilities, behaviors and goals.
  The actual execution and supervision is handled by the Lux runtime.
  """

  @type scheduled_beam :: {module(), String.t(), keyword()}
  @type collaboration_protocol :: :ask | :tell | :delegate | :request_review

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          module: module(),
          description: String.t(),
          goal: String.t(),
          prisms: [Lux.Prism.t()],
          beams: [Lux.Beam.t()],
          lenses: [Lux.Lens.t()],
          accepts_signals: [Lux.SignalSchema.t()],
          llm_config: map(),
          memory: list(),
          scheduled_beams: [scheduled_beam()],
          reflection_interval: non_neg_integer(),
          reflection: Lux.Reflection.t(),
          reflection_config: %{
            max_actions_per_reflection: pos_integer(),
            max_parallel_actions: pos_integer(),
            action_timeout: pos_integer()
          },
          collaboration_config: %{
            can_delegate: boolean(),
            can_request_help: boolean(),
            trusted_specters: [String.t()],
            collaboration_protocols: [collaboration_protocol()]
          }
        }

  defstruct id: nil,
            name: "",
            module: nil,
            description: "",
            goal: "",
            prisms: [],
            beams: [],
            lenses: [],
            accepts_signals: [],
            llm_config: %{
              provider: :openai,
              model: "gpt-4",
              temperature: 0.7,
              max_tokens: 1000
            },
            memory: [],
            scheduled_beams: [],
            reflection_interval: 60_000,
            reflection: nil,
            reflection_config: %{
              max_actions_per_reflection: 5,
              max_parallel_actions: 2,
              action_timeout: 30_000
            },
            collaboration_config: %{
              can_delegate: true,
              can_request_help: true,
              trusted_specters: [],
              collaboration_protocols: [:ask, :tell, :delegate, :request_review]
            }

  @callback reflect(t(), context :: map()) :: {:ok, [action]} | {:error, term()}
            when action: {module(), map()}

  @callback handle_signal(t(), Lux.Signal.t()) :: {:ok, [action]} | :ignore | {:error, term()}
            when action: {module(), map()}

  @callback learn(t(), capability :: term()) :: {:ok, t()} | {:error, term()}

  @doc """
  Performs a reflection cycle for the specter.
  This is called periodically based on reflection_interval.
  """
  def reflect(%__MODULE__{reflection_config: config} = specter, context) do
    with {:ok, actions, updated_reflection} <-
           Lux.Reflection.reflect(specter.reflection, specter, context),
         limited_actions <- Enum.take(actions, config.max_actions_per_reflection),
         chunked_actions <- chunk_actions(limited_actions, config.max_parallel_actions) do
      updated_specter = %{specter | reflection: updated_reflection}
      {:ok, execute_action_chunks(chunked_actions, config.action_timeout), updated_specter}
    end
  end

  @doc """
  Schedules a beam to run periodically using cron expression.
  The cron expression follows the standard cron format:

  * * * * *
  │ │ │ │ │
  │ │ │ │ └── day of week (0 - 6) (0 is Sunday)
  │ │ │ └──── month (1 - 12)
  │ │ └────── day of month (1 - 31)
  │ └──────── hour (0 - 23)
  └────────── minute (0 - 59)
  """
  def schedule_beam(
        %__MODULE__{scheduled_beams: beams} = specter,
        beam_module,
        cron_expression,
        opts \\ []
      ) do
    case Crontab.CronExpression.Parser.parse(cron_expression) do
      {:ok, _} ->
        {:ok, %{specter | scheduled_beams: [{beam_module, cron_expression, opts} | beams]}}

      {:error, reason} ->
        {:error, {:invalid_cron_expression, reason}}
    end
  end

  @doc """
  Removes a scheduled beam.
  """
  def unschedule_beam(%__MODULE__{scheduled_beams: beams} = specter, beam_module) do
    updated_beams = Enum.reject(beams, fn {module, _, _} -> module == beam_module end)
    {:ok, %{specter | scheduled_beams: updated_beams}}
  end

  @doc """
  Checks which beams should run based on their cron expressions.
  Returns a list of beam modules that should be executed.
  """
  def get_due_beams(%__MODULE__{scheduled_beams: beams}) do
    now = DateTime.utc_now()

    Enum.filter(beams, fn {_module, cron_expression, _opts} ->
      {:ok, cron} = Crontab.CronExpression.Parser.parse(cron_expression)
      Crontab.DateChecker.matches_date?(cron, now)
    end)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.Specter

      # Default implementations that can be overridden
      @impl true
      def reflect(specter, context) do
        Lux.Specter.reflect(specter, context)
      end

      @impl true
      def handle_signal(_specter, _signal) do
        :ignore
      end

      @impl true
      def learn(specter, _capability) do
        {:ok, specter}
      end

      defoverridable reflect: 2, handle_signal: 2, learn: 2
    end
  end

  @doc """
  Creates a new specter from the given attributes
  """
  def new(attrs) when is_map(attrs) do
    llm_config = build_llm_config(attrs[:llm_config])

    reflection =
      Lux.Reflection.new(%{
        name: attrs[:name] || "Anonymous Reflection",
        description: attrs[:description] || "Default reflection process",
        llm_config: llm_config
      })

    struct(__MODULE__, %{
      id: Map.get(attrs, :id, Lux.UUID.generate()),
      name: Map.get(attrs, :name, "Anonymous Specter"),
      module: Map.get(attrs, :module),
      description: Map.get(attrs, :description, ""),
      goal: Map.get(attrs, :goal, ""),
      llm_config: llm_config,
      prisms: Map.get(attrs, :prisms, []),
      beams: Map.get(attrs, :beams, []),
      lenses: Map.get(attrs, :lenses, []),
      accepts_signals: Map.get(attrs, :accepts_signals, []),
      memory: [],
      scheduled_beams: Map.get(attrs, :scheduled_beams, []),
      reflection_interval: Map.get(attrs, :reflection_interval, 60_000),
      reflection: reflection,
      reflection_config: build_reflection_config(attrs[:reflection_config]),
      collaboration_config: build_collaboration_config(attrs[:collaboration_config])
    })
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  # Private helpers

  defp default_llm_config do
    %{
      provider: :openai,
      model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000
    }
  end

  defp chunk_actions(actions, chunk_size) do
    actions
    |> Enum.chunk_every(chunk_size)
  end

  defp execute_action_chunks(chunks, timeout) do
    results =
      chunks
      |> Enum.map(fn chunk ->
        chunk
        |> Enum.map(&Task.async(fn -> execute_action(&1, timeout) end))
        |> Task.await_many(timeout)
      end)
      |> List.flatten()

    {:ok, results}
  end

  defp execute_action({module, params}, timeout) do
    try do
      Task.await(Task.async(fn -> apply(module, :run, [params]) end), timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp build_llm_config(config) do
    Map.merge(default_llm_config(), config || %{})
  end

  defp build_reflection_config(config) do
    Map.merge(
      %{max_actions_per_reflection: 5, max_parallel_actions: 2, action_timeout: 30_000},
      config || %{}
    )
  end

  defp build_collaboration_config(config) do
    Map.merge(
      %{
        can_delegate: true,
        can_request_help: true,
        trusted_specters: [],
        collaboration_protocols: [:ask, :tell, :delegate, :request_review]
      },
      config || %{}
    )
  end

  @doc """
  Handles collaboration between specters.
  """
  def collaborate(
        %__MODULE__{collaboration_config: config} = specter,
        target_specter,
        protocol,
        payload
      ) do
    with true <- config.can_delegate || protocol != :delegate,
         true <- config.can_request_help || protocol != :request_review,
         true <- protocol in config.collaboration_protocols,
         true <- target_specter.id in config.trusted_specters do
      do_collaborate(protocol, specter, target_specter, payload)
    else
      false -> {:error, :unauthorized}
    end
  end

  defp do_collaborate(:ask, _specter, _target_specter, _question) do
    # Implement question-answer protocol
    {:ok, :not_implemented}
  end

  defp do_collaborate(:tell, _specter, _target_specter, _information) do
    # Implement information sharing protocol
    {:ok, :not_implemented}
  end

  defp do_collaborate(:delegate, _specter, _target_specter, _task) do
    # Implement task delegation protocol
    {:ok, :not_implemented}
  end

  defp do_collaborate(:request_review, _specter, _target_specter, _work) do
    # Implement peer review protocol
    {:ok, :not_implemented}
  end

  def handle_signal(specter, signal) do
    apply(specter.module, :handle_signal, [specter, signal])
  end
end

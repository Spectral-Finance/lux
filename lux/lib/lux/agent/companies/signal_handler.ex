defmodule Lux.Agent.Companies.SignalHandler do
  @moduledoc """
  Behaviour module that defines how company agents should handle different types of signals.

  This module defines callbacks for:
  1. Task-related signals (assignments, updates, completion)
  2. Objective-related signals (evaluation, next steps)
  3. General signal handling
  """

  alias Lux.Schemas.Companies.ObjectiveSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  @doc """
  Called when a task is assigned to the agent.
  Should evaluate the task and determine how to complete it.
  """
  @callback handle_task_assignment(TaskSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called to update task progress.
  Should evaluate current state and send progress update.
  """
  @callback handle_task_update(TaskSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called when a task is completed.
  Should validate completion and prepare completion report.
  """
  @callback handle_task_completion(TaskSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called when a task fails.
  Should prepare failure report with reason and any recovery steps.
  """
  @callback handle_task_failure(TaskSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called for CEO agents to evaluate objective progress.
  Should assess current state and decide next actions.
  """
  @callback handle_objective_evaluation(ObjectiveSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called for CEO agents to determine next step in objective.
  Should analyze dependencies and assign appropriate agent.
  """
  @callback handle_objective_next_step(ObjectiveSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called to update objective status.
  Should evaluate progress and update objective metadata.
  """
  @callback handle_objective_update(ObjectiveSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @doc """
  Called when an objective is completed.
  Should validate all steps are complete and prepare completion report.
  """
  @callback handle_objective_completion(ObjectiveSignal.signal(), context :: map()) ::
              {:ok, Signal.t()} | {:error, term()}

  @optional_callbacks [
    handle_task_assignment: 2,
    handle_task_update: 2,
    handle_task_completion: 2,
    handle_task_failure: 2,
    handle_objective_evaluation: 2,
    handle_objective_next_step: 2,
    handle_objective_update: 2,
    handle_objective_completion: 2
  ]

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Lux.Agent.Companies.SignalHandler

      @signal_handler_functions {TaskSignal, {__MODULE__, :handle_task_signal}}
      @signal_handler_functions {ObjectiveSignal, {__MODULE__, :handle_objective_signal}}

      def handle_task_signal(%Signal{payload: %{"type" => type}} = signal, context) do
        case type do
          "assignment" -> handle_task_assignment(signal, context)
          "status_update" -> handle_task_update(signal, context)
          "completion" -> handle_task_completion(signal, context)
          "failure" -> handle_task_failure(signal, context)
          _ -> {:error, :unsupported_task_type}
        end
      end

      def handle_objective_signal(%Signal{payload: %{"type" => type}} = signal, context) do
        case type do
          "evaluate" -> handle_objective_evaluation(signal, context)
          "next_step" -> handle_objective_next_step(signal, context)
          "status_update" -> handle_objective_update(signal, context)
          "completion" -> handle_objective_completion(signal, context)
          _ -> {:error, :unsupported_objective_type}
        end
      end

      # Default implementations that return :not_implemented
      @impl Lux.Agent.Companies.SignalHandler
      def handle_task_assignment(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_task_update(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_task_completion(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_task_failure(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_objective_evaluation(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_objective_next_step(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_objective_update(_, _), do: {:error, :not_implemented}

      @impl Lux.Agent.Companies.SignalHandler
      def handle_objective_completion(_, _), do: {:error, :not_implemented}

      # Allow overriding any of these functions
      defoverridable handle_task_assignment: 2,
                     handle_task_update: 2,
                     handle_task_completion: 2,
                     handle_task_failure: 2,
                     handle_objective_evaluation: 2,
                     handle_objective_next_step: 2,
                     handle_objective_update: 2,
                     handle_objective_completion: 2
    end
  end
end

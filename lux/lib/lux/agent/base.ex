defmodule Lux.Agent.Base do
  @moduledoc """
  Base implementation for Lux agents.

  This module provides common functionality for all agents:
  1. Signal handling and routing
  2. State management
  3. LLM interaction
  4. Tool usage
  """

  use GenServer

  alias Lux.Agent.SignalHandler
  alias Lux.Signal
  alias Lux.Signal.Router

  require Logger

  defstruct [
    :id,
    :type,
    :goal,
    :capabilities,
    :router,
    :hub,
    :llm,
    :tools,
    :memory,
    state: %{},
    metadata: %{}
  ]

  # Client API

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    agent =
      struct!(__MODULE__, %{
        id: Keyword.fetch!(opts, :id),
        type: Keyword.fetch!(opts, :type),
        goal: Keyword.fetch!(opts, :goal),
        capabilities: Keyword.fetch!(opts, :capabilities),
        router: Keyword.fetch!(opts, :router),
        hub: Keyword.fetch!(opts, :hub),
        llm: Keyword.fetch!(opts, :llm),
        tools: Keyword.get(opts, :tools, []),
        memory: Keyword.get(opts, :memory, Lux.Memory.Simple),
        metadata: Keyword.get(opts, :metadata, %{})
      })

    Logger.info("Starting agent: #{agent.id}")
    Logger.info("Type: #{agent.type}")
    Logger.info("Goal: #{agent.goal}")
    Logger.info("Capabilities: #{inspect(agent.capabilities)}")

    {:ok, agent}
  end

  # Server Callbacks

  def handle_info({:signal, signal}, agent) do
    Logger.debug("Agent #{agent.id} received signal: #{inspect(signal)}")

    context = %{
      agent: agent,
      tools: agent.tools,
      memory: agent.memory,
      state: agent.state
    }

    case handle_signal(signal, context) do
      {:ok, response} ->
        # Route response back through router
        Router.route(response,
          router: agent.router,
          hub: agent.hub
        )

        {:noreply, agent}

      {:ok, response, new_state} ->
        Router.route(response,
          router: agent.router,
          hub: agent.hub
        )

        {:noreply, %{agent | state: new_state}}

      {:error, reason} ->
        Logger.error("Agent #{agent.id} failed to handle signal: #{inspect(reason)}")
        # Send error response
        error_response = %Signal{
          id: Lux.UUID.generate(),
          schema_id: signal.schema_id,
          payload: %{
            type: "failure",
            error: inspect(reason)
          },
          recipient: signal.sender,
          metadata: %{
            original_signal_id: signal.id
          }
        }

        Router.route(error_response,
          router: agent.router,
          hub: agent.hub
        )

        {:noreply, agent}
    end
  end

  # Private Functions

  defp handle_signal(signal, context) do
    # Delegate to the signal handler implementation
    module = context.agent.__struct__

    if function_exported?(module, :handle_signal, 2) do
      module.handle_signal(signal, context)
    else
      {:error, :no_signal_handler}
    end
  end

  # Default implementations for common agent functions

  @doc """
  Uses the agent's LLM to evaluate a task or make a decision.
  """
  def evaluate(prompt, context, opts \\ []) do
    llm = context.agent.llm
    llm.complete(prompt, opts)
  end

  @doc """
  Uses a specific tool from the agent's toolset.
  """
  def use_tool(tool_name, args, context) do
    case Enum.find(context.tools, &(&1.name == tool_name)) do
      nil -> {:error, :tool_not_found}
      tool -> tool.run(args, context)
    end
  end

  @doc """
  Stores information in the agent's memory.
  """
  def remember(key, value, context) do
    context.memory.store(key, value)
  end

  @doc """
  Retrieves information from the agent's memory.
  """
  def recall(key, context) do
    context.memory.retrieve(key)
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      use SignalHandler

      # Re-export the base agent functions
      defdelegate evaluate(prompt, context, opts \\ []), to: Lux.Agent.Base
      defdelegate use_tool(tool_name, args, context), to: Lux.Agent.Base
      defdelegate remember(key, value, context), to: Lux.Agent.Base
      defdelegate recall(key, context), to: Lux.Agent.Base

      # Allow customizing initialization
      def init(opts) do
        Lux.Agent.Base.init(opts)
      end

      # Allow overriding any callbacks
      defoverridable init: 1
    end
  end
end

defmodule Lux.Agent.Companies.SignalHandler.DefaultImplementation do
  @moduledoc """
  Default implementation of company signal handler that uses LLM to:
  1. Analyze tasks and determine required tools
  2. Select appropriate tools for the task
  3. Execute tools in sequence and evaluate results
  """

  @behaviour Lux.Agent.Companies.SignalHandler

  alias Lux.LLM
  alias Lux.LLM.ResponseSignal
  alias Lux.Schemas.Companies.ObjectiveSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  require Logger

  def handle_signal(%Signal{schema_id: TaskSignal} = signal, context) do
    case signal.payload["type"] do
      "assignment" -> handle_task_assignment(signal, context)
      "status_update" -> handle_task_update(signal, context)
      _ -> {:error, :unsupported_task_type}
    end
  end

  def handle_signal(%Signal{schema_id: ObjectiveSignal} = signal, context) do
    case signal.payload["type"] do
      "evaluate" -> handle_objective_evaluation(signal, context)
      "status_update" -> handle_objective_update(signal, context)
      "completion" -> handle_objective_completion(signal, context)
      _ -> {:error, :unsupported_task_type}
    end
  end

  def handle_signal(_signal, _context) do
    {:error, :unsupported_schema}
  end

  @impl true
  def handle_task_assignment(%Signal{payload: payload} = _signal, context) do
    Logger.info("Analyzing task: #{payload["title"]}")
    Logger.debug("Task context: #{inspect(context)}")
    Logger.debug("Task payload: #{inspect(payload)}")

    # Get required capabilities from payload
    required_capabilities = payload["required_capabilities"] || []
    # Get role capabilities (not agent capabilities)
    role_capabilities = context.role.capabilities || []

    if has_required_capabilities?(context.role, required_capabilities) do
      # Create success response with metadata
      {:ok,
       %Signal{
         id: Lux.UUID.generate(),
         schema_id: TaskSignal,
         payload: %{
           "type" => "completion",
           "task_id" => payload["task_id"],
           "objective_id" => payload["objective_id"],
           "status" => "completed",
           "result" => %{
             "success" => true,
             "used_capabilities" => required_capabilities
           }
         },
         metadata: %{
           "agent_capabilities" => role_capabilities
         },
         timestamp: DateTime.utc_now()
       }}
    else
      # Create failure response with capability mismatch details
      {:ok,
       %Signal{
         id: Lux.UUID.generate(),
         schema_id: TaskSignal,
         payload: %{
           "type" => "failure",
           "task_id" => payload["task_id"],
           "objective_id" => payload["objective_id"],
           "status" => "failed",
           "result" => %{
             "success" => false,
             "error" => "Agent lacks required capabilities",
             "required_capabilities" => required_capabilities,
             "agent_capabilities" => role_capabilities
           }
         },
         timestamp: DateTime.utc_now()
       }}
    end
  end

  @impl true
  def handle_task_update(%Signal{payload: payload} = signal, _context) do
    # Create progress update response
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: TaskSignal,
       payload:
         Map.merge(payload, %{
           "type" => "status_update",
           "status" => "in_progress"
         }),
       recipient: signal.sender,
       timestamp: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_objective_evaluation(%Signal{payload: payload} = signal, context) do
    Logger.debug("Evaluating objective with context: #{inspect(context)}")

    case evaluate_next_step(payload, context) do
      {:ok, evaluation} ->
        Logger.debug("Evaluation successful: #{inspect(evaluation)}")

        {:ok,
         %Signal{
           id: Lux.UUID.generate(),
           schema_id: ObjectiveSignal,
           payload:
             Map.merge(payload, %{
               "type" => "evaluate",
               "evaluation" => evaluation
             }),
           recipient: signal.sender,
           timestamp: DateTime.utc_now()
         }}

      {:error, :no_hub_configured} ->
        Logger.error("No hub configured for agent selection")

        {:ok,
         %Signal{
           id: Lux.UUID.generate(),
           schema_id: ObjectiveSignal,
           payload:
             Map.merge(payload, %{
               "type" => "evaluate",
               "evaluation" => %{
                 "decision" => "error",
                 "error" => "No hub configured for agent selection",
                 "reasoning" => "Cannot proceed without a configured hub"
               }
             }),
           recipient: signal.sender,
           timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.error("Failed to evaluate objective: #{inspect(reason)}")

        {:ok,
         %Signal{
           id: Lux.UUID.generate(),
           schema_id: ObjectiveSignal,
           payload:
             Map.merge(payload, %{
               "type" => "evaluate",
               "evaluation" => %{
                 "decision" => "error",
                 "error" => reason,
                 "reasoning" => "Failed to evaluate next step"
               }
             }),
           recipient: signal.sender,
           timestamp: DateTime.utc_now()
         }}
    end
  end

  @impl true
  def handle_objective_update(%Signal{payload: payload} = signal, _context) do
    # Update objective progress and status
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: ObjectiveSignal,
       payload:
         Map.merge(payload, %{
           "type" => "status_update",
           "context" => %{
             "progress" => calculate_progress(payload)
           }
         }),
       recipient: signal.sender,
       timestamp: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_objective_completion(%Signal{payload: payload} = signal, _context) do
    # Handle objective completion
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: ObjectiveSignal,
       payload:
         Map.merge(payload, %{
           "type" => "completion",
           "context" => %{
             "progress" => 100
           },
           "evaluation" => %{
             "decision" => "complete",
             "reasoning" => "All steps completed successfully"
           }
         }),
       recipient: signal.sender,
       timestamp: DateTime.utc_now()
     }}
  end

  # Private Functions

  defp analyze_task(payload, context) do
    Logger.debug("Starting task analysis with payload: #{inspect(payload)}")

    prompt = """
    Analyze this task and determine if it is possible to complete with the available tools:
    Title: #{payload["title"]}
    Description: #{payload["description"]}

    Consider:
    1. Is this task possible to complete with the available tools?
    2. What type of task is this?
    3. What tools might be needed?
    4. What should the output look like?
    5. Are there any constraints to consider?
    6. What artifacts should be produced?
    7. Are the requirements clear and complete?
    """

    # Let OpenAI handle the tool schema transformation
    tools = get_available_tools(context)

    llm_opts =
      context
      |> get_llm_opts()
      |> Map.put(:json_response, true)
      |> Map.put(:json_schema, %{
        "name" => "AnalysisFeasibilitySchema",
        "type" => "object",
        "properties" => %{
          "feasibility" => %{
            "type" => "object",
            "properties" => %{
              "possible" => %{"type" => "boolean"},
              "reason" => %{"type" => "string"}
            }
          }
        }
      })

    Logger.debug("Available tools for analysis: #{inspect(tools)}")

    case LLM.call(prompt, tools, llm_opts) do
      {:ok, %LLM.Response{structured_output: analysis}} ->
        Logger.debug("Analysis successful: #{inspect(analysis)}")

        case analysis do
          %{"feasibility" => %{"possible" => false, "reason" => reason}} ->
            {:error, :analysis, "Task is impossible: #{reason}"}

          _ ->
            {:ok, analysis}
        end

      {:ok, %Signal{schema_id: ResponseSignal} = response} ->
        Logger.debug("Analysis successful: #{inspect(response)}")

        case response.payload.content do
          %{"feasibility" => %{"possible" => false, "reason" => reason}} ->
            {:error, :analysis, "Task is impossible: #{reason}"}

          content ->
            {:ok, content}
        end

      {:error, reason} ->
        Logger.error("Analysis failed: #{inspect(reason)}")
        {:error, :analysis, reason}
    end
  end

  defp execute_task(analysis, context) do
    Logger.debug("Starting task execution with analysis: #{inspect(analysis)}")

    prompt = """
    Given this task analysis:
    #{format_analysis(analysis)}

    Execute the task using the available tools.
    Determine:
    1. Which tools to use
    2. What parameters to provide
    3. How to combine the results

    If at any point you determine the task cannot be completed, explain why.
    """

    # Let OpenAI handle tool execution
    llm_opts = get_llm_opts(context)
    tools = get_available_tools(context)
    Logger.debug("Available tools for execution: #{inspect(tools)}")

    case LLM.call(prompt, tools, llm_opts) do
      {:ok, %LLM.Response{structured_output: result}} ->
        Logger.debug("Execution successful: #{inspect(result)}")
        {:ok, result}

      {:ok, %Signal{schema_id: ResponseSignal} = response} ->
        Logger.debug("Execution successful: #{inspect(response)}")
        {:ok, response.payload.content}

      {:error, reason} ->
        Logger.error("Execution failed: #{inspect(reason)}")
        {:error, :execution, reason}
    end
  end

  defp format_analysis(analysis) when is_map(analysis) do
    """
    Task Type: #{analysis["task_type"]}
    Required Capabilities: #{format_data(analysis["required_capabilities"])}
    Expected Outputs: #{format_data(analysis["expected_outputs"])}
    Success Criteria: #{format_data(analysis["success_criteria"])}
    """
  end

  defp format_data(data) when is_map(data) or is_list(data) do
    Jason.encode!(data)
  end

  defp format_data(data), do: inspect(data)

  defp get_available_tools(context) do
    (context.beams || []) ++ (context.lenses || []) ++ (context.prisms || [])
  end

  defp get_next_step_index(%{"steps" => steps}) do
    # Find the index of the next pending step
    case Enum.find_index(steps, &(&1["status"] == "pending")) do
      # If no pending steps, return length (completion)
      nil -> length(steps)
      index -> index
    end
  end

  defp get_next_step_index(_), do: 0

  defp calculate_progress(%{"steps" => steps}) do
    completed = Enum.count(steps, &(&1["status"] == "completed"))
    total = length(steps)

    case total do
      0 -> 0
      _ -> round(completed / total * 100)
    end
  end

  defp calculate_progress(_), do: 0

  def get_llm_opts(%{template_opts: %{llm_opts: llm_opts}}) do
    llm_opts
  end

  def get_llm_opts(%{llm_config: llm_opts}), do: llm_opts

  def get_llm_opts(_), do: raise("No LLM configuration found to run the task.")

  defp evaluate_next_step(payload, context) do
    Logger.debug("Evaluating next step with context: #{inspect(context)}")
    next_step_index = get_next_step_index(payload)

    # Get the next step's required capabilities
    required_capabilities = get_step_capabilities(payload, next_step_index)
    Logger.debug("Required capabilities for next step: #{inspect(required_capabilities)}")

    # Find the best agent based on capabilities
    case select_agent_for_capabilities(required_capabilities, context) do
      {:ok, agent_id} ->
        Logger.debug("Found matching agent: #{agent_id}")

        {:ok,
         %{
           "decision" => "continue",
           "next_step_index" => next_step_index,
           "assigned_agent" => agent_id,
           "required_capabilities" => required_capabilities,
           "reasoning" => "Selected agent with matching capabilities for next step"
         }}

      {:error, :no_hub_configured} = error ->
        Logger.debug("No hub configured in context")
        error

      {:error, reason} = error ->
        Logger.debug("Error selecting agent: #{inspect(reason)}")
        error
    end
  end

  defp get_step_capabilities(payload, step_index) do
    steps = payload["steps"] || []

    case Enum.at(steps, step_index) do
      nil -> []
      step -> step["required_capabilities"] || []
    end
  end

  defp select_agent_for_capabilities(required_capabilities, context) do
    # Get hub from either context.agent.hub or context.hub
    hub = get_in(context, [:agent, :hub]) || context[:hub]
    Logger.debug("Looking for hub in context: #{inspect(hub)}")

    case hub do
      nil ->
        Logger.error("No hub found in context")
        {:error, :no_hub_configured}

      hub ->
        Logger.debug("Found hub: #{inspect(hub)}")
        # Get all available agents from the hub
        agents = Lux.AgentHub.list_agents(hub)
        Logger.debug("Found agents: #{inspect(agents)}")
        # Filter agents by required capabilities
        matching_agents =
          Enum.filter(agents, fn agent ->
            has_required_capabilities?(agent, required_capabilities)
          end)

        case matching_agents do
          [] -> {:error, :no_matching_agent}
          [best_match | _] -> {:ok, best_match.agent.id}
        end
    end
  end

  defp has_required_capabilities?(%{capabilities: capabilities}, required)
       when is_list(required) do
    Enum.all?(required, &(&1 in capabilities))
  end

  defp has_required_capabilities?(%{agent: %{capabilities: capabilities}}, required)
       when is_list(required) do
    Enum.all?(required, &(&1 in capabilities))
  end

  defp has_required_capabilities?(_, _), do: false
end

defmodule Lux.Beam do
  @moduledoc """
  Beams orchestrate workflows by combining multiple Prisms into sequential, parallel,
  or conditional execution paths with dependency management and execution logging.

  ## Overview

  A Beam is a workflow definition that:
  - Combines multiple Prisms into a cohesive workflow
  - Supports sequential, parallel, and conditional execution
  - Handles parameter passing between steps
  - Manages execution logging and error handling
  - Can be used by Agents for agent coordination

  ## Creating a Beam

  To create a beam, use the `Lux.Beam` module:
  ```elixir
  defmodule MyApp.Beams.TradingWorkflow do
    use Lux.Beam,
      name: "Trading Workflow",
      description: "Analyzes and executes trades",
      input_schema: %{
        type: :object,
        properties: %{
          symbol: %{type: :string},
          amount: %{type: :number}
        },
        required: ["symbol", "amount"]
      },
      output_schema: %{
        type: :object,
        properties: %{
          trade_id: %{type: :string}
        },
        required: ["trade_id"]
      },
      generate_execution_log: true

    sequence do
      step(:market_data, MyApp.Prisms.MarketData, %{symbol: :symbol})

      parallel do
        step(:technical, MyApp.Prisms.TechnicalAnalysis,
          %{data: {:ref, "market_data"}},
          retries: 3,
          store_io: true)

        step(:sentiment, MyApp.Prisms.SentimentAnalysis,
          %{symbol: :symbol},
          timeout: :timer.seconds(30))
      end

      branch {__MODULE__, :should_trade?} do
        true -> step(:execute, MyApp.Prisms.ExecuteTrade, %{
          symbol: :symbol,
          amount: :amount,
          signals: {:ref, "technical"}
        })
        false -> step(:skip, MyApp.Prisms.LogDecision, %{
          reason: "Unfavorable conditions"
        })
      end
    end

    def should_trade?(ctx) do
      ctx.technical.score > 0.7 && ctx.sentiment.confidence > 0.8
    end
  end
  ```

  ## Complex Example: Agent Management Beam

  Here's an example of a more complex beam that manages other agents:

  More examples:
  This beam:
  1. Evaluates current workload and team performance
  2. Decides whether to hire new agents or terminate underperforming ones
  3. Handles the hiring/firing process including resource allocation

  ```elixir
  defmodule HiringManagerBeam do
    use Lux.Beam, generate_execution_log: true

    sequence do
      # First evaluate current workforce metrics
      step(:workforce_metrics, WorkforceAnalysisPrism, %{
        team_size: {:ref, "current_team_size"},
        performance_data: {:ref, "agent_performance_metrics"},
        workload_stats: {:ref, "current_workload"}
      })

      # Check if we need to scale the team
      branch {__MODULE__, :needs_scaling?} do
        :scale_up ->
          sequence do
            # Find suitable candidates
            step(:candidate_search, AgentSearchPrism, %{
              required_skills: {:ref, "workforce_metrics.skill_gaps"},
              count: {:ref, "workforce_metrics.hiring_needs"}
            })

            # Interview and evaluate candidates
            step(:candidate_evaluation, AgentEvaluationPrism, %{
              candidates: {:ref, "candidate_search.results"},
              evaluation_criteria: {:ref, "workforce_metrics.requirements"}
            })

            # Onboard selected candidates
            step(:onboarding, AgentOnboardingPrism, %{
              selected_agents: {:ref, "candidate_evaluation.approved_candidates"},
              resource_allocation: {:ref, "workforce_metrics.available_resources"}
            })
          end

        :scale_down ->
          sequence do
            # Identify underperforming agents
            step(:performance_review, PerformanceReviewPrism, %{
              agents: {:ref, "workforce_metrics.underperforming_agents"},
              criteria: {:ref, "workforce_metrics.performance_thresholds"}
            })

            # Handle agent termination
            step(:termination, AgentTerminationPrism, %{
              agents: {:ref, "performance_review.agents_to_terminate"},
              reassign_tasks: true
            })
          end

        :maintain ->
          # Just update team metrics and resources
          step(:team_maintenance, TeamMaintenancePrism, %{
            current_team: {:ref, "workforce_metrics.active_agents"},
            resource_updates: {:ref, "workforce_metrics.resource_adjustments"}
          })
      end
    end

    def needs_scaling?(ctx) do
      metrics = ctx["workforce_metrics"]
      cond do
        metrics.workload_ratio > 0.8 and metrics.performance_score > 0.7 -> :scale_up
        metrics.efficiency_score < 0.4 or metrics.resource_strain > 0.9 -> :scale_down
        true -> :maintain
      end
    end
  end
  ```

  ## Step Configuration Options

  Steps can be configured with various options:

  - `timeout`: Maximum execution time (default: 5 minutes)
  - `retries`: Number of retry attempts (default: 0)
  - `retry_backoff`: Delay between retries in ms (default: 1000)
  - `track`: Enable step tracking (default: false)
  - `dependencies`: List of dependent step IDs (default: [])
  - `store_io`: Store step I/O in execution log (default: false)
  - `fallback`: Module or function to handle step failures (default: nil)

  ## Parameter References

  Steps can reference outputs from previous steps using the `{:ref, "step_id"}` syntax:

  ```elixir
  step(:analysis, AnalysisPrism, %{
    data: {:ref, "data_collection"},
    config: {:ref, "settings.analysis_config"}
  })
  ```

  ## Execution Logging

  When `generate_execution_log: true` is set, beams generate detailed execution logs
  including step timing, inputs, outputs, and errors.

  See `t:execution_log/0` for the full log structure.
  """

  use Lux.Types

  defstruct id: nil,
            name: "",
            description: "",
            input_schema: nil,
            output_schema: nil,
            definition: [],
            timeout: :timer.minutes(5),
            generate_execution_log: false

  @type execution_log :: %{
          beam_id: String.t(),
          started_by: String.t(),
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          status: :running | :completed | :failed,
          input: map() | nil,
          output: map() | nil,
          steps: [
            %{
              id: String.t(),
              name: String.t(),
              started_at: DateTime.t(),
              completed_at: DateTime.t() | nil,
              input: map() | nil,
              output: map() | nil,
              error: term() | nil,
              status: :pending | :running | :completed | :failed
            }
          ]
        }

  @type step :: %{
          id: String.t(),
          module: module(),
          params: map(),
          opts: %{
            timeout: pos_integer(),
            retries: non_neg_integer(),
            retry_backoff: pos_integer(),
            track: boolean(),
            dependencies: [String.t()],
            store_io: boolean(),
            fallback: module() | (map() -> {:continue | :stop, term()}) | nil
          }
        }

  @type schema :: map()

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          input_schema: nullable(schema()),
          output_schema: nullable(schema()),
          definition: [step()],
          timeout: pos_integer(),
          generate_execution_log: boolean()
        }

  defmacro __using__(opts) do
    quote do
      import Lux.Beam, only: [step: 3, step: 4, parallel: 1, sequence: 1, branch: 2]

      alias Lux.Beam

      @beam %Beam{
        id: Keyword.get(unquote(opts), :id, Lux.UUID.generate()),
        name: Keyword.get(unquote(opts), :name, __MODULE__ |> Module.split() |> Enum.join(".")),
        description: unquote(opts[:description]),
        input_schema: unquote(opts[:input_schema]),
        output_schema: unquote(opts[:output_schema]),
        timeout: Keyword.get(unquote(opts), :timeout, :timer.minutes(5)),
        generate_execution_log: Keyword.get(unquote(opts), :generate_execution_log, false)
      }

      if not Module.get_attribute(__MODULE__, :sequence_defined) do
        raise "The Lux.Beam module requires a sequence block to be defined"
      end

      def view, do: %{@beam | definition: __steps__()}

      def run(input, opts \\ []), do: Lux.Beam.Runner.run(view(), input, opts)
    end
  end

  @doc """
  Creates a new beam from attributes
  """
  def new(attrs) when is_list(attrs) do
    %__MODULE__{
      id: attrs[:id] || Lux.UUID.generate(),
      name: attrs[:name] || "",
      description: attrs[:description] || "",
      input_schema: attrs[:input_schema],
      output_schema: attrs[:output_schema],
      definition: attrs[:definition],
      timeout: attrs[:timeout] || :timer.minutes(5),
      generate_execution_log: attrs[:generate_execution_log] || false
    }
  end

  # DSL Macros
  defmacro step(id, module, params, opts \\ []) do
    quote do
      %{
        id: unquote(id),
        module: unquote(module),
        params: unquote(params),
        opts:
          Enum.into(unquote(opts), %{
            timeout: :timer.minutes(5),
            retries: 0,
            retry_backoff: 1000,
            track: false,
            dependencies: [],
            store_io: false,
            fallback: nil
          })
      }
    end
  end

  defmacro sequence(do: {:__block__, _, steps}) do
    if has_parent?(__CALLER__) do
      quote do
        {:sequence, unquote(steps)}
      end
    else
      Module.put_attribute(__CALLER__.module, :sequence_defined, true)
      build_steps(steps)
    end
  end

  defmacro sequence(do: single_step) do
    if has_parent?(__CALLER__) do
      quote do
        {:sequence, [unquote(single_step)]}
      end
    else
      Module.put_attribute(__CALLER__.module, :sequence_defined, true)
      build_steps([single_step])
    end
  end

  defmacro parallel(do: {:__block__, _, steps}) do
    if has_parent?(__CALLER__) do
      quote do
        {:parallel, unquote(steps)}
      end
    else
      build_steps(steps)
    end
  end

  defmacro parallel(do: single_step) do
    if has_parent?(__CALLER__) do
      quote do
        {:parallel, [unquote(single_step)]}
      end
    else
      build_steps([single_step])
    end
  end

  defmacro branch(condition, do: blocks) do
    quote do
      {:branch, {__MODULE__, unquote(extract_function_name(condition))},
       unquote(transform_branch_blocks(blocks))}
    end
  end

  defp has_parent?(caller) do
    cond do
      # used outside of module (e.g. livebook cell)
      is_nil(caller.function) and is_nil(caller.module) -> true
      # used in nested block
      not is_nil(caller.function) and not is_nil(caller.module) -> true
      # top level
      is_nil(caller.function) and not is_nil(caller.module) -> false
    end
  end

  defp build_steps(steps) do
    seq =
      quote do
        {:sequence, unquote(steps)}
      end

    quote do
      def __steps__ do
        unquote(seq)
      end
    end
  end

  # Serialization helpers
  defp extract_function_name({:&, _, [{:/, _, [{name, _, _}, _arity]}]}) do
    name
  end

  defp extract_function_name({{:__MODULE__, _, _}, function}) when is_atom(function) do
    function
  end

  defp extract_function_name({module, function}) when is_atom(module) and is_atom(function) do
    function
  end

  defp transform_branch_blocks(blocks) when is_list(blocks) do
    Enum.map(blocks, fn {:->, _, [[condition], consequent]} ->
      {transform_condition(condition), consequent}
    end)
  end

  defp transform_branch_blocks({:->, _, [[condition], consequent]}) do
    [{transform_condition(condition), consequent}]
  end

  defp transform_branch_blocks({:__block__, _, blocks}) do
    transform_branch_blocks(blocks)
  end

  defp transform_condition({:_, _, _}), do: :_
  defp transform_condition(condition), do: condition

  @doc """
  Validates a beam definition at compile time
  """
  def validate!(%__MODULE__{
        input_schema: input_schema,
        output_schema: output_schema,
        definition: definition
      }) do
    with :ok <- validate_schema(input_schema),
         :ok <- validate_schema(output_schema) do
      validate_definition(definition)
    end
  end

  defp validate_schema(nil), do: :ok
  defp validate_schema(schema) when is_map(schema), do: :ok
  defp validate_schema(_), do: {:error, :invalid_schema}

  defp validate_definition(nil), do: {:error, :missing_definition}
  defp validate_definition(definition) when is_list(definition), do: :ok
  defp validate_definition(_), do: {:error, :invalid_definition}
end

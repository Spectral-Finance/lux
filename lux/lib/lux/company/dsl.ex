defmodule Lux.Company.DSL do
  @moduledoc """
  A simple DSL for defining companies with a CEO, custom roles, and objectives.

  ## Example

      defmodule MyApp.Companies.ContentTeam do
        use Lux.Company

        company do
          name "Content Creation Team"
          mission "Create engaging content efficiently"

          # Every company has a CEO
          has_ceo "Content Director" do
            agent MyApp.Agents.ContentDirector
            goal "Direct content creation and review"
            can "plan"
            can "review"
            can "approve"
          end

          # Group member roles together
          members do
            has_role "Lead Researcher" do
              agent {"researcher-123", :research_hub}
              goal "Research and analyze topics"
              can "research"
              can "analyze"
              can "summarize"
            end

            has_role "Senior Writer" do
              agent MyApp.Agents.Writer
              goal "Create and edit content"
              can "write"
              can "edit"
              can "draft"
            end
          end

          # Define objectives
          objective :create_blog_post do
            description "Create a well-researched blog post"
            success_criteria "Published post with >1000 views"
            steps [
              "Research the topic",
              "Create an outline",
              "Write first draft",
              "Review and edit",
              "Publish"
            ]
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Lux.Company.DSL

      require Logger

      Logger.debug("Using Lux.Company.DSL in #{__MODULE__}")
      Module.register_attribute(__MODULE__, :company_config, accumulate: false)
      Module.register_attribute(__MODULE__, :company_defined, accumulate: false)
      @before_compile Lux.Company.DSL

      def view do
        %Lux.Company{__company__() | module: __MODULE__}
      end
    end
  end

  defmacro __before_compile__(env) do
    require Logger

    Logger.debug("Before compile hook for #{env.module}")

    if not Module.get_attribute(env.module, :company_defined) do
      raise "The Lux.Company module requires a company block to be defined"
    end

    # Get the final company config for validation
    config = Module.get_attribute(env.module, :company_config)
    Logger.debug("Final company config: #{inspect(config)}")
    validate!(config)

    quote do
      def __company__ do
        @company_config
      end
    end
  end

  defmacro company(do: block) do
    quote do
      @company_defined true
      @company_config %Lux.Company{
        id: Lux.UUID.generate(),
        name: nil,
        mission: nil,
        module: __MODULE__,
        ceo: nil,
        roles: [],
        objectives: []
      }
      unquote(block)
    end
  end

  defmacro name(value) do
    quote do
      @company_config Map.put(@company_config, :name, unquote(value))
    end
  end

  defmacro mission(value) do
    quote do
      @company_config Map.put(@company_config, :mission, unquote(value))
    end
  end

  defmacro has_ceo(name, do: block) do
    quote do
      var!(current_role) = %{
        type: :ceo,
        id: Lux.UUID.generate(),
        name: unquote(name),
        goal: nil,
        capabilities: [],
        agent: nil,
        hub: nil
      }

      unquote(block)
      @company_config Map.put(@company_config, :ceo, var!(current_role))
    end
  end

  defmacro members(do: block) do
    quote do
      var!(role_group) = :member
      unquote(block)
    end
  end

  defmacro has_role(name, do: block) do
    quote do
      var!(current_role) = %{
        type: var!(role_group),
        id: Lux.UUID.generate(),
        name: unquote(name),
        goal: nil,
        capabilities: [],
        agent: nil,
        hub: nil
      }

      unquote(block)
      @company_config Map.update!(@company_config, :roles, &[var!(current_role) | &1])
    end
  end

  defmacro goal(value) do
    quote do
      var!(current_role) = Map.put(var!(current_role), :goal, unquote(value))
    end
  end

  defmacro can(capability) do
    quote do
      var!(current_role) =
        Map.update!(
          var!(current_role),
          :capabilities,
          &[unquote(capability) | &1]
        )
    end
  end

  defmacro agent(value) do
    quote do
      {hub, agent_ref} =
        case unquote(value) do
          {id, hub} when is_binary(id) and is_atom(hub) -> {hub, unquote(value)}
          module when is_atom(module) -> {nil, module}
        end

      var!(current_role) =
        Map.merge(var!(current_role), %{
          agent: agent_ref,
          hub: hub
        })
    end
  end

  defmacro objective(name, do: block) do
    quote do
      var!(current_objective) = %Lux.Company.Objective{
        id: Lux.UUID.generate(),
        name: unquote(name),
        description: nil,
        success_criteria: nil,
        steps: [],
        input_schema: nil
      }

      unquote(block)

      @company_config Map.update!(@company_config, :objectives, &[var!(current_objective) | &1])
    end
  end

  defmacro description(value) do
    quote do
      var!(current_objective) = Map.put(var!(current_objective), :description, unquote(value))
    end
  end

  defmacro success_criteria(value) do
    quote do
      var!(current_objective) =
        Map.put(var!(current_objective), :success_criteria, unquote(value))
    end
  end

  defmacro steps(value) when is_list(value) do
    quote do
      var!(current_objective) = Map.put(var!(current_objective), :steps, unquote(value))
    end
  end

  defmacro steps(value) when is_binary(value) do
    quote do
      steps =
        unquote(value)
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      var!(current_objective) = Map.put(var!(current_objective), :steps, steps)
    end
  end

  defmacro input(schema) do
    quote do
      var!(current_objective) = Map.put(var!(current_objective), :input_schema, unquote(schema))
    end
  end

  defp validate!(config) do
    cond do
      is_nil(config.name) ->
        raise CompileError, description: "Company requires a name"

      is_nil(config.mission) ->
        raise CompileError, description: "Company requires a mission"

      is_nil(config.ceo) ->
        raise CompileError, description: "Company requires a CEO"

      true ->
        validate_role!(config.ceo, :ceo)

        Enum.each(config.roles, &validate_role!(&1, :member))

        Enum.each(config.objectives, &validate_objective!/1)
    end
  end

  # Private validation functions
  defp validate_role!(role, type) do
    if is_nil(role.name) do
      raise CompileError,
        description: "#{String.capitalize(to_string(type))} role requires a name"
    end

    if is_nil(role.agent) do
      raise CompileError,
        description: "#{String.capitalize(to_string(type))} role '#{role.name}' requires an agent"
    end

    if is_nil(role.goal) do
      raise CompileError,
        description: "#{String.capitalize(to_string(type))} role '#{role.name}' requires a goal"
    end

    if is_nil(role.capabilities) or role.capabilities == [] do
      raise CompileError,
        description:
          "#{String.capitalize(to_string(type))} role '#{role.name}' requires at least one capability"
    end
  end

  defp validate_objective!(objective) do
    if is_nil(objective.description) do
      raise CompileError,
        description: "Objective :#{objective.name} requires a description"
    end

    if is_nil(objective.success_criteria) do
      raise CompileError,
        description: "Objective :#{objective.name} requires success criteria"
    end

    if is_nil(objective.steps) or objective.steps == [] do
      raise CompileError,
        description: "Objective :#{objective.name} requires at least one step"
    end

    if is_nil(objective.input_schema) do
      raise CompileError,
        description: "Objective :#{objective.name} requires an input schema"
    end
  end
end

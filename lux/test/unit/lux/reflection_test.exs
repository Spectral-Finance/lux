defmodule Lux.ReflectionTest do
  use UnitCase, async: true

  alias Lux.Reflection

  describe "new/1" do
    test "creates a new reflection with default values" do
      reflection = Reflection.new()
      assert reflection.id != nil
      assert reflection.name == ""
      assert reflection.description == ""
      assert reflection.state == :idle
      assert reflection.last_reflection_time != nil
      assert reflection.patterns == []
      assert reflection.history == []
      assert reflection.metrics.learning_rate == 0.1
    end

    test "creates a new reflection with custom values" do
      attrs = %{
        name: "Test Reflection",
        description: "A test reflection",
        llm_config: %{model: "gpt-3.5-turbo"}
      }

      reflection = Reflection.new(attrs)
      assert reflection.name == "Test Reflection"
      assert reflection.description == "A test reflection"
      assert reflection.llm_config.model == "gpt-3.5-turbo"
      # Default values should still be set
      assert reflection.id != nil
      assert reflection.state == :idle
    end
  end

  describe "reflect/3" do
    setup do
      reflection =
        Reflection.new(%{
          name: "Test Reflection",
          description: "Test reflection process"
        })

      agent = %Lux.Agent{
        id: "test-agent",
        name: "Test Agent",
        goal: "Test goal"
      }

      context = %{
        current_task: "test task",
        environment: "test"
      }

      {:ok, reflection: reflection, agent: agent, context: context}
    end

    test "performs reflection and returns actions with updated reflection", %{
      reflection: reflection,
      agent: agent,
      context: context
    } do
      {:ok, actions, updated_reflection} = Reflection.reflect(reflection, agent, context)

      # Check actions
      assert is_list(actions)
      assert length(actions) > 0
      {module, params} = List.first(actions)
      assert is_atom(module)
      assert is_map(params)

      # Check updated reflection
      assert updated_reflection.state == :idle
      assert updated_reflection.last_reflection_time > reflection.last_reflection_time
      assert length(updated_reflection.history) > length(reflection.history)
      assert updated_reflection.metrics.total_reflections == 1
      assert updated_reflection.metrics.total_actions == length(actions)
    end

    test "handles errors gracefully", %{reflection: reflection, agent: agent} do
      bad_context = nil
      {:error, _reason, updated_reflection} = Reflection.reflect(reflection, agent, bad_context)
      assert updated_reflection.state == :idle
    end
  end

  describe "update_context/2" do
    test "merges new context with existing context" do
      reflection = Reflection.new()
      existing_context = %{key1: "value1"}
      reflection = %{reflection | context: existing_context}

      new_context = %{key2: "value2"}
      updated_reflection = Reflection.update_context(reflection, new_context)

      assert updated_reflection.context.key1 == "value1"
      assert updated_reflection.context.key2 == "value2"
    end

    test "new values override existing values" do
      reflection = Reflection.new()
      existing_context = %{key: "old_value"}
      reflection = %{reflection | context: existing_context}

      new_context = %{key: "new_value"}
      updated_reflection = Reflection.update_context(reflection, new_context)

      assert updated_reflection.context.key == "new_value"
    end
  end

  describe "learn/1" do
    test "analyzes history and updates patterns" do
      reflection = Reflection.new()

      history_entry = %{
        timestamp: DateTime.utc_now(),
        reflection: %{
          "thoughts" => "Test thoughts",
          "patterns_identified" => ["Pattern1"]
        },
        actions: []
      }

      reflection = %{reflection | history: [history_entry]}

      updated_reflection = Reflection.learn(reflection)

      assert updated_reflection.state == :idle
      assert is_list(updated_reflection.patterns)
      # Metrics should be updated
      assert updated_reflection.metrics != reflection.metrics
    end

    test "handles empty history" do
      reflection = Reflection.new()
      updated_reflection = Reflection.learn(reflection)

      assert updated_reflection.state == :idle
      assert updated_reflection.patterns == []
    end
  end

  describe "private functions" do
    test "format_history/1 formats history entries correctly" do
      now = DateTime.utc_now()

      history = [
        %{
          timestamp: now,
          reflection: %{"thoughts" => "Test thought 1"},
          actions: []
        },
        %{
          timestamp: DateTime.add(now, -1, :hour),
          reflection: %{"thoughts" => "Test thought 2"},
          actions: []
        }
      ]

      formatted = apply(Reflection, :format_history, [history])

      assert is_binary(formatted)
      assert String.contains?(formatted, "Test thought 1")
      assert String.contains?(formatted, "Test thought 2")
    end

    test "update_metrics/2 correctly updates metrics" do
      reflection = Reflection.new()
      actions = [{Elixir.TestModule, %{}}]

      updated_reflection = apply(Reflection, :update_metrics, [reflection, actions])

      assert updated_reflection.metrics.total_actions == 1
      assert updated_reflection.metrics.total_reflections == 1
    end

    test "update_patterns/2 maintains unique patterns and limits size" do
      reflection = Reflection.new()
      existing_patterns = ["Pattern1", "Pattern2"]
      reflection = %{reflection | patterns: existing_patterns}

      new_patterns = ["Pattern2", "Pattern3"]
      updated_reflection = apply(Reflection, :update_patterns, [reflection, new_patterns])

      assert length(updated_reflection.patterns) == 3
      assert "Pattern1" in updated_reflection.patterns
      assert "Pattern2" in updated_reflection.patterns
      assert "Pattern3" in updated_reflection.patterns
    end
  end
end

defmodule Lux.Engine.Subscription.PatternTest do
  use ExUnit.Case
  alias Lux.Engine.Subscription.Pattern
  alias Lux.Signal

  describe "new/2" do
    test "creates pattern with exact matches" do
      pattern_map = %{schema_id: "test.event", sender: "agent1", recipient: "agent2"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == pattern_map
      assert pattern.wildcards == %{}
      assert pattern.regex_patterns == %{}
      assert pattern.priority == 0
    end

    test "extracts wildcards from pattern" do
      pattern_map = %{schema_id: "test.*", sender: "agent?", recipient: "agent2"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{recipient: "agent2"}
      assert pattern.wildcards == %{schema_id: "test.*", sender: "agent?"}
      assert pattern.regex_patterns == %{}
    end

    test "extracts regex patterns" do
      pattern_map = %{schema_id: "~r/test\\.\\w+/", sender: "agent1"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{sender: "agent1"}
      assert pattern.wildcards == %{}
      assert map_size(pattern.regex_patterns) == 1
      assert Regex.match?(pattern.regex_patterns.schema_id, "test.event")
    end

    test "sets priority from options" do
      pattern = Pattern.new(%{schema_id: "test.event"}, priority: 10)
      assert pattern.priority == 10
    end
  end

  describe "match?/2" do
    test "matches exact values" do
      pattern = Pattern.new(%{schema_id: "test.event", sender: "agent1"})

      signal = %Signal{
        schema_id: "test.event",
        sender: "agent1",
        recipient: "agent2",
        payload: %{}
      }

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches wildcards" do
      pattern = Pattern.new(%{schema_id: "test.*", sender: "agent?"})

      signal = %Signal{
        schema_id: "test.event",
        sender: "agent1",
        recipient: "agent2",
        payload: %{}
      }

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches regex patterns" do
      pattern = Pattern.new(%{schema_id: "~r/test\\.\\w+/"})

      signal = %Signal{
        schema_id: "test.event",
        sender: "agent1",
        recipient: "agent2",
        payload: %{}
      }

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "does not match when required field is missing" do
      pattern = Pattern.new(%{schema_id: "test.event", sender: "agent1"})

      signal = %Signal{
        schema_id: "other.event",
        sender: "agent1",
        recipient: "agent2",
        payload: %{}
      }

      assert :nomatch = Pattern.match?(pattern, signal)
    end

    test "matches with priority" do
      pattern = Pattern.new(%{schema_id: "test.event"}, priority: 10)

      signal = %Signal{
        schema_id: "test.event",
        sender: "agent1",
        recipient: "agent2",
        payload: %{}
      }

      assert {:ok, 10} = Pattern.match?(pattern, signal)
    end
  end
end

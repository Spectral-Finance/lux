defmodule Lux.Engine.Subscription.PatternTest do
  use ExUnit.Case
  alias Lux.Engine.Subscription.Pattern

  describe "new/2" do
    test "creates a pattern with exact matches" do
      pattern_map = %{type: "test.event", value: 42}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{type: "test.event", value: 42}
      assert pattern.wildcards == %{}
      assert pattern.regex_patterns == %{}
      assert pattern.priority == 0
    end

    test "extracts wildcards from pattern" do
      pattern_map = %{type: "test.*", value: "*"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{}
      assert pattern.wildcards == %{type: "test.*", value: "*"}
      assert pattern.regex_patterns == %{}
    end

    test "extracts regex patterns" do
      pattern_map = %{id: "~r/[0-9]+/", type: "test"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{type: "test"}
      assert pattern.wildcards == %{}
      assert map_size(pattern.regex_patterns) == 1
      assert Regex.regex?(pattern.regex_patterns.id)
    end

    test "sets priority from options" do
      pattern = Pattern.new(%{}, priority: 10)
      assert pattern.priority == 10
    end
  end

  describe "match?/2" do
    test "matches exact patterns" do
      pattern = Pattern.new(%{type: "test.event", value: 42})
      signal = %{type: "test.event", value: 42, extra: "field"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "does not match when fields are missing" do
      pattern = Pattern.new(%{type: "test.event", missing: "field"})
      signal = %{type: "test.event"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches wildcard patterns" do
      pattern = Pattern.new(%{type: "test.*", value: "*"})
      signal = %{type: "test.event", value: "anything"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches regex patterns" do
      pattern = Pattern.new(%{id: "~r/^[0-9]{3}$/"})
      signal = %{id: "123"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "returns priority with match" do
      pattern = Pattern.new(%{type: "test"}, priority: 10)
      signal = %{type: "test"}

      assert {:ok, 10} = Pattern.match?(pattern, signal)
    end
  end

  describe "apply_transformations/2" do
    test "applies transformations to matching fields" do
      transformations = %{
        value: &(&1 * 2),
        name: &String.upcase/1
      }

      pattern = Pattern.new(%{}, transformations: transformations)
      signal = %{value: 21, name: "test", other: "field"}

      transformed = Pattern.apply_transformations(pattern, signal)
      assert transformed.value == 42
      assert transformed.name == "TEST"
      assert transformed.other == "field"
    end

    test "ignores transformations for missing fields" do
      transformations = %{missing: &(&1 * 2)}
      pattern = Pattern.new(%{}, transformations: transformations)
      signal = %{value: 21}

      transformed = Pattern.apply_transformations(pattern, signal)
      assert transformed == signal
    end
  end
end

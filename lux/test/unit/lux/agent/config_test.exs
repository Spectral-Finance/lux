defmodule Lux.Unit.Agent.ConfigTest do
  use UnitCase, async: true

  alias Lux.Agent.Config

  describe "new/1" do
    test "creates config from valid attributes" do
      attrs = %{
        "id" => "test-agent",
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Test.Agent",
        "template" => "company_agent",
        "template_opts" => %{
          "llm_config" => %{"temperature" => 0.7}
        }
      }

      assert {:ok, config} = Config.new(attrs)
      assert config.id == "test-agent"
      assert config.name == "Test Agent"
      assert config.description == "A test agent"
      assert config.goal == "Testing"
      assert config.module == "Test.Agent"
      assert config.template == :company_agent
      assert get_in(config.template_opts, ["llm_config", "temperature"]) == 0.7
    end

    test "handles missing required fields" do
      attrs = %{"name" => "Test Agent"}
      assert {:error, {:missing_fields, missing}} = Config.new(attrs)
      assert :id in missing
      assert :description in missing
      assert :goal in missing
      assert :module in missing
    end

    test "handles invalid types" do
      attrs = %{
        # Should be string
        "id" => 123,
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Test.Agent"
      }

      assert {:error, {:invalid_type, :id, :string}} = Config.new(attrs)
    end
  end

  describe "validate/1" do
    test "validates valid config" do
      config = %Config{
        id: "test-agent",
        name: "Test Agent",
        description: "A test agent",
        goal: "Testing",
        module: "Test.Agent"
      }

      assert :ok = Config.validate(config)
    end

    test "validates required fields" do
      config = %Config{
        name: "Test Agent"
      }

      assert {:error, {:missing_fields, missing}} = Config.validate(config)
      assert :id in missing
      assert :description in missing
      assert :goal in missing
      assert :module in missing
    end

    test "validates field types" do
      config = %Config{
        id: 123,
        name: "Test Agent",
        description: "A test agent",
        goal: "Testing",
        module: "Test.Agent"
      }

      assert {:error, {:invalid_type, :id, :string}} = Config.validate(config)
    end
  end
end

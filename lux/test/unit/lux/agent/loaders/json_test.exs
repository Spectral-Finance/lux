defmodule Lux.Unit.Agent.Loaders.JsonTest do
  use UnitCase, async: true

  alias Lux.Agent.Config
  alias Lux.Agent.Loaders.Json

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lux_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "load/1" do
    test "loads from JSON string" do
      json = ~s({
        "id": "test-agent",
        "name": "Test Agent",
        "description": "A test agent",
        "goal": "Testing",
        "module": "Test.JsonAgent"
      })

      assert {:ok, [%Config{} = config]} = Json.load(json)
      assert config.id == "test-agent"
      assert config.module == "Test.JsonAgent"
    end

    test "loads from file", %{tmp_dir: tmp_dir} do
      config_map = %{
        "id" => "test-agent",
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Test.JsonAgent"
      }

      path = Path.join(tmp_dir, "agent.json")
      File.write!(path, Jason.encode!(config_map))

      assert {:ok, [%Config{} = config]} = Json.load(path)
      assert config.id == "test-agent"
      assert config.module == "Test.JsonAgent"
    end

    test "loads from directory", %{tmp_dir: tmp_dir} do
      config_map = %{
        "id" => "test-agent",
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Test.JsonAgent"
      }

      path = Path.join(tmp_dir, "agent.json")
      File.write!(path, Jason.encode!(config_map))

      assert {:ok, [%Config{} = config]} = Json.load(tmp_dir)
      assert config.id == "test-agent"
      assert config.module == "Test.JsonAgent"
    end

    test "handles empty directory", %{tmp_dir: tmp_dir} do
      assert {:error, :no_json_files_found} = Json.load(tmp_dir)
    end

    test "handles invalid source" do
      assert {:error, :invalid_source} = Json.load("not a file or json")
    end
  end

  describe "parse/1" do
    test "parses valid JSON" do
      json = ~s({
        "id": "test-agent",
        "name": "Test Agent",
        "description": "A test agent",
        "goal": "Testing",
        "module": "Test.JsonAgent",
        "template": "company_agent",
        "template_opts": {
          "llm_config": {"temperature": 0.7}
        }
      })

      assert {:ok, %Config{} = config} = Json.parse(json)
      assert config.id == "test-agent"
      assert config.template == :company_agent
      assert config.template_opts["llm_config"]["temperature"] == 0.7
    end

    test "handles invalid JSON" do
      assert {:error, %Jason.DecodeError{}} = Json.parse("{invalid")
    end

    test "validates required fields" do
      json = ~s({"name": "Invalid Agent"})
      assert {:error, {:missing_fields, _}} = Json.parse(json)
    end
  end
end

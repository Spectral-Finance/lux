defmodule Lux.TestingTest do
  use ExUnit.CASE, async: true

  alias Lux.Testing

  describe "setup_test_env/1" do
    test "creates test environment context" do
      assert {:ok, context} = Testing.setup_test_env()
      assert context.env == :test
      assert context.pid == self()
      assert Map.has_key?(context, :started_at)
    end

    test "creates context with API keys" do
      assert {:ok, context} = Testing.setup_test_env(api_keys: %{openai: "sk-test123"})
      assert context.api_keys.openai == "sk-test123"
    end

    test "creates context with mocks" do
      assert {:ok, context} =
               Testing.setup_test_env(
                 mock_lenses: [Lux.Lenses.Etherscan.Gas.GasOracleLens],
                 mock_prisms: []
               )

      assert length(context.mock_lenses) == 1
      assert context.mock_prisms == []
    end
  end

  describe "teardown_test_env/1" do
    test "returns ok" do
      {:ok, context} = Testing.setup_test_env()
      assert Testing.teardown_test_env(context) == :ok
    end
  end

  describe "build_sample_lens/1" do
    test "builds default sample lens" do
      lens = Testing.build_sample_lens()

      assert lens.name == "Sample Lens"
      assert lens.method == :get
      assert String.starts_with?(lens.url, "https://")
      assert is_map(lens.schema)
    end

    test "builds custom lens" do
      lens =
        Testing.build_sample_lens(
          name: "Custom API",
          url: "https://api.custom.com/v1/data",
          method: :post,
          description: "A custom test lens"
        )

      assert lens.name == "Custom API"
      assert lens.method == :post
      assert lens.description == "A custom test lens"
    end
  end

  describe "build_sample_prism/1" do
    test "builds default sample prism" do
      prism = Testing.build_sample_prism()

      assert prism.name == "Sample Prism"
      assert is_function(prism.handler)
      assert is_map(prism.input_schema)
    end

    test "builds prism with custom handler" do
      handler = fn input, _opts -> {:ok, %{result: input}} end

      prism = Testing.build_sample_prism(handler: handler, name: "Custom Prism")

      assert prism.name == "Custom Prism"
      assert prism.handler.(%{x: 1}, []) == {:ok, %{result: %{x: 1}}}
    end
  end

  describe "build_sample_beam/1" do
    test "builds default sample beam" do
      beam = Testing.build_sample_beam()

      assert beam.name == "Sample Beam"
      assert length(beam.steps) >= 2
      assert beam.trigger.type == :manual
    end

    test "builds beam with custom steps" do
      steps = [%{type: :map, config: %{fn: "double"}}]
      beam = Testing.build_sample_beam(steps: steps, trigger: %{type: :schedule})

      assert length(beam.steps) == 1
      assert beam.trigger.type == :schedule
    end
  end

  describe "generate_sample_data/1" do
    test "generates single lens" do
      data = Testing.generate_sample_data(type: :lens, count: 1)
      assert length(data) == 1
      assert Map.has_key?(hd(data), :name)
    end

    test "generates multiple prisms" do
      data = Testing.generate_sample_data(type: :prism, count: 3)
      assert length(data) == 3
      assert Enum.all?(data, &Map.has_key?(&1, :name))
    end

    test "generates beams" do
      data = Testing.generate_sample_data(type: :beam, count: 2)
      assert length(data) == 2
    end

    test "generates agents" do
      data = Testing.generate_sample_data(type: :agent, count: 1)
      assert hd(data).role == "researcher"
    end

    test "generates companies" do
      data = Testing.generate_sample_data(type: :company, count: 1)
      assert hd(data).status == :active
    end
  end

  describe "run_tests/1" do
    test "runs passing tests" do
      result =
        Testing.run_tests(
          tests: [
            fn -> :ok end,
            fn -> {:ok, 42} end
          ],
          verbose: false
        )

      assert result.total == 2
      assert result.passed == 2
      assert result.failed == 0
      assert result.errors == []
      assert result.duration_ms >= 0
    end

    test "counts failing tests" do
      result =
        Testing.run_tests(
          tests: [
            fn -> :ok end,
            fn -> raise "test failure" end
          ]
        )

      assert result.total == 2
      assert result.passed == 1
      assert result.failed == 1
      assert length(result.errors) == 1
    end

    test "handles empty test list" do
      result = Testing.run_tests(tests: [])
      assert result.total == 0
      assert result.passed == 0
      assert result.failed == 0
    end
  end

  describe "generate_github_actions/1" do
    test "generates valid YAML config" do
      assert {:ok, config} = Testing.generate_github_actions()

      assert String.contains?(config, "name: Lux CI")
      assert String.contains?(config, "mix test")
      assert String.contains?(config, "actions/checkout@v4")
      assert String.contains?(config, "elixir-ci:")
    end

    test "respects custom versions" do
      assert {:ok, config} =
               Testing.generate_github_actions(elixir_version: ["1.17", "1.18"])

      assert String.contains?(config, "'1.17'")
      assert String.contains?(config, "'1.18'")
    end
  end

  describe "generate_gitlab_ci/1" do
    test "generates valid GitLab CI config" do
      assert {:ok, config} = Testing.generate_gitlab_ci()

      assert String.contains?(config, "image: elixir:")
      assert String.contains?(config, "mix test")
      assert String.contains?(config, "credo:")
      assert String.contains?(config, "dialyzer:")
    end
  end

  describe "coverage_summary/1" do
    test "calculates coverage from files" do
      summary =
        Testing.coverage_summary(%{
          files: [
            %{name: "a.ex", coverage: 90},
            %{name: "b.ex", coverage: 70},
            %{name: "c.ex", coverage: 85}
          ],
          threshold: 80
        })

      assert summary.total_files == 3
      assert summary.average_coverage == 81.7
      assert summary.files_below_threshold == 1
    end

    test "handles empty files" do
      summary = Testing.coverage_summary(%{files: []})
      assert summary.total_files == 0
      assert summary.average_coverage == 0.0
    end
  end

  describe "create_fixture/2" do
    test "creates fixture file" do
      filepath = System.tmp_dir!() |> Path.join("test_fixture_#{System.unique_integer([:positive])}.exs")

      assert {:ok, path} = Testing.create_fixture(filepath, %{name: "test"})
      assert File.exists?(path)

      content = File.read!(path)
      assert String.contains?(content, "Auto-generated test fixture")

      File.rm(filepath)
    end
  end

  describe "validate_schema/2" do
    test "validates matching schema" do
      assert {:ok, %{}} =
               Testing.validate_schema(%{name: "test", value: 42}, %{
                 type: :object,
                 properties: %{
                   name: %{type: :string},
                   value: %{type: :integer}
                 }
               })
    end

    test "rejects non-matching types" do
      assert {:error, errors} =
               Testing.validate_schema("wrong", %{type: :integer})

      assert length(errors) > 0
    end

    test "validates required fields" do
      assert {:error, errors} =
               Testing.validate_schema(%{}, %{
                 type: :object,
                 properties: %{name: %{type: :string}},
                 required: [:name]
               })

      assert Enum.any?(errors, &String.contains?(&1, "Missing required field"))
    end
  end

  describe "assert_schema_matches!/2" do
    test "does not raise for valid schema" do
      assert Testing.assert_schema_matches!(%{name: "test"}, %{type: :object}) == :ok
    end

    test "raises on invalid schema" do
      assert_raise ExUnit.AssertionError, fn ->
        Testing.assert_schema_matches!("not_an_object", %{type: :integer})
      end
    end
  end
end

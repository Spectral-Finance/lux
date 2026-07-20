defmodule Lux.Testing do
  @moduledoc """
  Testing utilities and test fixtures for Lux applications.

  Provides helpers for:
  - Setting up test environments
  - Creating mock lenses, prisms, and beams
  - Running integration tests
  - Test data generation
  - Assertion helpers for Lux-specific patterns
  - CI/CD pipeline configuration generation

  ## Features

  - Test environment setup/teardown macros
  - Mock module generators
  - Sample data factories
  - Integration test helpers
  - Coverage report generation
  - CI configuration export (GitHub Actions, GitLab CI)
  - Test result aggregation

  ## Examples

      use Lux.Testing.Case

      test "lens processes data correctly" do
        lens = build_lens(:weather)
        result = Lens.focus(lens, %{q: "London"})
        assert result.temperature > 0
      end
  """

  alias Lux.Config

  @type test_fixture :: %{
          required(:name) => String.t(),
          required(:type) => :lens | :prism | :beam | :agent,
          optional(:data) => map()
        }

  @type ci_config :: %{
          required(:provider) => :github | :gitlab | :jenkins,
          required(:config) => String.t()
        }

  # Client API

  @doc """
  Creates a test environment context with mocked dependencies.

  ## Options

    * `:env` - Environment to simulate (default: :test)
    * `:mock_lenses` - List of lens modules to mock
    * `:mock_prisms` - List of prism modules to mock
    * `:api_keys` - Mock API keys map

  ## Examples

      iex> Lux.Testing.setup_test_env()
      {:ok, context}

      iex> Lux.Testing.setup_test_env(api_keys: %{openai: "test_key"})
      {:ok, context}
  """
  @spec setup_test_env(keyword()) :: {:ok, map()} | {:error, term()}
  def setup_test_env(opts \\ []) do
    env = Keyword.get(opts, :env, :test)
    api_keys = Keyword.get(opts, :api_keys, %{})
    mock_lenses = Keyword.get(opts, :mock_lenses, [])
    mock_prisms = Keyword.get(opts, :mock_prisms, [])

    context = %{
      env: env,
      api_keys: api_keys,
      mock_lenses: mock_lenses,
      mock_prisms: mock_prisms,
      started_at: DateTime.utc_now(),
      pid: self()
    }

    # Set test environment variables
    Enum.each(api_keys, fn {key, value} ->
      System.put_env("LUX_API_KEY_#{String.upcase(to_string(key))}", to_string(value))
    end)

    {:ok, context}
  end

  @doc """
  Tears down the test environment and restores original settings.

  ## Examples

      iex> Lux.Testing.teardown_test_env(context)
      :ok
  """
  @spec teardown_test_env(map()) :: :ok
  def teardown_test_env(context) when is_map(context) do
    # Restore environment variables
    Enum.each(context.api_keys || [], fn {key, _value} ->
      System.delete_env("LUX_API_KEY_#{String.upcase(to_string(key))}")
    end)

    :ok
  end

  @doc """
  Builds a sample lens for testing.

  ## Options

    * `:name` - Lens name
    * `:url` - Endpoint URL
    * `:method` - HTTP method
    * `:schema` - Request/response schema
    * `:response` - Mock response data

  ## Examples

      iex> Lux.Testing.build_sample_lens(name: "Test API", url: "https://api.test.com/data")
      %Lux.Lens{name: "Test API", ...}
  """
  @spec build_sample_lens(keyword()) :: map()
  def build_sample_lens(opts \\ []) do
    %{
      name: Keyword.get(opts, :name, "Sample Lens"),
      module_name: Keyword.get(opts, :module_name, "Lux.Testing.SampleLens"),
      url: Keyword.get(opts, :url, "https://api.example.com/v1/sample"),
      method: Keyword.get(opts, :method, :get),
      params: Keyword.get(opts, :params, %{}),
      headers: Keyword.get(opts, :headers, []),
      description: Keyword.get(opts, :description, "Sample lens for testing"),
      schema: Keyword.get(opts, :schema, %{
        type: :object,
        properties: %{
          query: %{type: :string, description: "Search query"},
          limit: %{type: :integer, description: "Results limit"}
        },
        required: ["query"]
      }),
      after_focus: Keyword.get(opts, :after_focus, fn body -> {:ok, body} end)
    }
  end

  @doc """
  Builds a sample prism for testing.

  ## Options

    * `:name` - Prism name
    * `:handler` - Handler function
    * `:input_schema` - Input validation schema
    * `:output_schema` - Output schema

  ## Examples

      iex> Lux.Testing.build_sample_prism(name: "Test Prism")
      %{name: "Test Prism", handler: #Function<...>, ...}
  """
  @spec build_sample_prism(keyword()) :: map()
  def build_sample_prism(opts \\ []) do
    handler = Keyword.get(opts, :handler, fn input, _opts -> {:ok, input} end)

    %{
      name: Keyword.get(opts, :name, "Sample Prism"),
      module_name: Keyword.get(opts, :module_name, "Lux.Testing.SamplePrism"),
      handler: handler,
      input_schema: Keyword.get(opts, :input_schema, %{
        type: :object,
        properties: %{action: %{type: :string}}
      }),
      output_schema: Keyword.get(opts, :output_schema, %{
        type: :object,
        properties: %{result: %{type: :any}}
      }),
      description: Keyword.get(opts, :description, "Sample prism for testing")
    }
  end

  @doc """
  Builds a sample beam for testing.

  ## Options

    * `:name` - Beam name
    * `:steps` - List of processing steps
    * `:trigger` - Trigger configuration

  ## Examples

      iex> Lux.Testing.build_sample_beam(name: "Test Beam")
      %{name: "Test Beam", steps: [...], ...}
  """
  @spec build_sample_beam(keyword()) :: map()
  def build_sample_beam(opts \\ []) do
    steps = Keyword.get(opts, :steps, [
      %{type: :filter, config: %{condition: "always_true"}},
      %{type: :transform, config: %{fn: "identity"}}
    ])

    %{
      name: Keyword.get(opts, :name, "Sample Beam"),
      module_name: Keyword.get(opts, :module_name, "Lux.Testing.SampleBeam"),
      steps: steps,
      trigger: Keyword.get(opts, :trigger, %{type: :manual}),
      description: Keyword.get(opts, :description, "Sample beam for testing")
    }
  end

  @doc """
  Generates sample test data for various entity types.

  ## Options

    * `:type` - Data type (:lens, :prism, :beam, :agent, :company)
    * `:count` - Number of records to generate (default: 1)

  ## Examples

      iex> Lux.Testing.generate_sample_data(type: :lens, count: 3)
      [%{name: "...", ...}, ...]
  """
  @spec generate_sample_data(keyword()) :: [map()]
  def generate_sample_data(opts \\ []) do
    type = Keyword.get(opts, :type, :lens)
    count = Keyword.get(opts, :count, 1)

    Enum.map(1..count, fn i ->
      case type do
        :lens ->
          build_sample_lens(
            name: "Test Lens #{i}",
            url: "https://api.example.com/v1/test/#{i}"
          )

        :prism ->
          build_sample_prism(name: "Test Prism #{i}")

        :beam ->
          build_sample_beam(name: "Test Beam #{i}")

        :agent ->
          %{
            name: "Test Agent #{i}",
            company: "Test Company #{i}",
            role: "researcher",
            skills: ["analysis", "reporting"],
            status: :active
          }

        :company ->
          %{
            name: "Test Company #{i}",
            agents: ["Agent #{i}"],
            objectives: ["Complete task #{i}"],
            status: :active
          }

        _ ->
          %{type: type, id: i, name: "Sample #{type} #{i}"}
      end
    end)
  end

  @doc """
  Runs a test suite and returns results.

  ## Options

    * `:tests` - List of test functions to run
    * `:timeout` - Per-test timeout in ms (default: 30000)
    * `:verbose` - Print progress (default: false)

  ## Examples

      iex> Lux.Testing.run_tests(tests: [&test_1/0, &test_2/0])
      %{total: 2, passed: 2, failed: 0, duration_ms: 150}
  """
  @spec run_tests(keyword()) :: %{
          total: integer(),
          passed: integer(),
          failed: integer(),
          errors: [term()],
          duration_ms: integer()
        }
  def run_tests(opts \\ []) do
    tests = Keyword.get(opts, :tests, [])
    timeout = Keyword.get(opts, :timeout, 30000)
    verbose = Keyword.get(opts, :verbose, false)

    start_time = System.monotonic_time(:millisecond)
    results = %{total: length(tests), passed: 0, failed: 0, errors: []}

    Enum.each(tests, fn test_fn ->
      case catch_error_timeout(test_fn, timeout) do
        {:ok, _} ->
          results.passed += 1

          if verbose do
            IO.puts("✅ PASS: #{inspect(test_fn)}")
          end

        {:error, reason} ->
          results.failed += 1
          results.errors = results.errors ++ [{test_fn, reason}]

          if verbose do
            IO.puts("❌ FAIL: #{inspect(test_fn)} — #{inspect(reason)}")
          end
      end
    end)

    end_time = System.monotonic_time(:millisecond)
    Map.put(results, :duration_ms, end_time - start_time)
  end

  @doc """
  Generates GitHub Actions CI configuration for Lux.

  ## Options

    * `:elixir_version` - Elixir version matrix (default: ["1.18"])
    * `:otp_version` - OTP version matrix (default: ["26.2"])
    * `:on_events` - CI trigger events (default: ["push", "pull_request"])

  ## Examples

      iex> Lux.Testing.generate_github_actions()
      {:ok, "# This file was auto-generated by Lux.Testing\nname: Lux CI\\n..."}
  """
  @spec generate_github_actions(keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_github_actions(opts \\ []) do
    elixir_versions = Keyword.get(opts, :elixir_version, ["1.18"])
    otp_versions = Keyword.get(opts, :otp_version, ["26.2"])
    on_events = Keyword.get(opts, :on_events, ["push", "pull_request"])

    matrix_elixir = Enum.map_join(elixir_versions, ", ", fn v -> "'#{v}'" end)
    matrix_otp = Enum.map_join(otp_versions, ", ", fn v -> "'#{v}'" end)
    events = Enum.map_join(on_events, ", ", fn e -> "'#{e}'" end)

    config = """
    # This file was auto-generated by Lux.Testing
    name: Lux CI

    on:
      push:
        branches: [main, master]
      pull_request:
        branches: [main, master]

    jobs:
      elixir-ci:
        runs-on: ubuntu-latest
        strategy:
          fail-fast: false
          matrix:
            elixir: [#{matrix_elixir}]
            otp: [#{matrix_otp}]

        steps:
          - uses: actions/checkout@v4

          - name: Set up Elixir
            uses: erlef/setup-beam@v1
            with:
              elixir-version: \${{ matrix.elixir }}
              otp-version: \${{ matrix.otp }}

          - name: Restore dependencies cache
            uses: actions/cache@v4
            with:
              path: |
                deps
                _build
              key: \${{ runner.os }}-elixir-\${{ matrix.elixir }}-otp-\${{ matrix.otp }}-\${{ hashFiles('**/mix.lock') }}
              restore-keys: |
                \${{ runner.os }}-elixir-\${{ matrix.elixir }}-otp-\${{ matrix.otp }}-

          - name: Install dependencies
            run: mix deps.get

          - name: Compile
            run: mix compile --warnings-as-errors

          - name: Run tests
            run: mix test

          - name: Check formatting
            run: mix format --check-formatted

          - name: Credo
            run: mix credo --strict

          - name: Dialyzer
            run: mix dialyzer --format github
    """

    {:ok, config}
  end

  @doc """
  Generates GitLab CI configuration for Lux.

  ## Examples

      iex> Lux.Testing.generate_gitlab_ci()
      {:ok, "image: elixir:1.18\\nstages:\\n  - test\\n..."}
  """
  @spec generate_gitlab_ci(keyword()) :: {:ok, String.t()}
  def generate_gitlab_ci(opts \\ []) do
    elixir_version = Keyword.get(opts, :elixir_version, "1.18-otp-26")

    config = """
    image: elixir:#{elixir_version}

    stages:
      - test
      - analyze

    variables:
      MIX_ENV: test

    cache:
      key: \${CI_COMMIT_REF_SLUG}
      paths:
        - deps/
        - _build/

    test:
      stage: test
      script:
        - mix deps.get
        - mix compile --warnings-as-errors
        - mix test
        - mix format --check-formatted
      artifacts:
        when: always
        reports:
          junit: cover/_build/test/junit/lux.xml

    credo:
      stage: analyze
      script:
        - mix credo --strict
      allow_failure: true

    dialyzer:
      stage: analyze
      script:
        - mix dialyzer --format github
      allow_failure: true
    """

    {:ok, config}
  end

  @doc """
  Generates a test coverage report summary.

  ## Examples

      iex> Lux.Testing.coverage_summary(%{files: [%{name: "lib/a.ex", covered: 90}]})
      "%{total_files: 1, average_coverage: 90.0, files_below_threshold: 0}"
  """
  @spec coverage_summary(map()) :: map()
  def coverage_summary(data) when is_map(data) do
    files = Map.get(data, :files, [])
    threshold = Map.get(data, :threshold, 80)

    total = length(files)

    if total == 0 do
      %{total_files: 0, average_coverage: 0.0, files_below_threshold: 0}
    else
      avg =
        files
        |> Enum.map(fn f -> Map.get(f, :coverage, 0) end)
        |> Enum.sum()
        |> Kernel./(total)

      below =
        files
        |> Enum.count(fn f -> Map.get(f, :coverage, 0) < threshold end)

      %{
        total_files: total,
        average_coverage: Float.round(avg, 1),
        files_below_threshold: below
      }
    end
  end

  @doc """
  Creates a test fixture file for a given module.

  ## Examples

      iex> Lux.Testing.create_fixture("lux/test/support/sample_lens.exs")
      {:ok, "lux/test/support/sample_lens.exs"}
  """
  @spec create_fixture(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def create_fixture(path, data \\ %{}) do
    content = render_fixture(data)

    File.mkdir_p!(Path.dirname(path))

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Asserts that a value matches a Lux schema.

  ## Examples

      iex> Lux.Testing.assert_schema_matches!(%{name: "test", value: 42}, %{
      ...>   type: :object,
      ...>   properties: %{name: %{type: :string}, value: %{type: :integer}}
      ...> })
      :ok
  """
  @spec assert_schema_matches!(any(), map()) :: :ok | no_return()
  def assert_schema_matches!(value, schema) do
    case validate_schema(value, schema) do
      {:ok, _} -> :ok
      {:error, errors} ->
        raise ExUnit.AssertionError, "Schema validation failed: #{Enum.join(errors, ", ")}"
    end
  end

  @doc """
  Validates a value against a schema definition.

  ## Examples

      iex> Lux.Testing.validate_schema(%{name: "test"}, %{type: :object})
      {:ok, %{}}
  """
  @spec validate_schema(any(), map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_schema(_value, %{type: :object, properties: props} = schema) when is_map(_value) do
    errors = []

    errors =
      Enum.reduce(props, errors, fn {name, prop_schema}, acc ->
        if Map.has_key?(_value, name) do
          case validate_schema(Map.get(_value, name), prop_schema) do
            {:ok, _} -> acc
            {:error, prop_errors} -> acc ++ ["#{name}: #{Enum.join(prop_errors, ', ')}"]
          end
        else
          if schema.required && Enum.member?(schema.required, name) do
            acc ++ ["Missing required field: #{name}"]
          else
            acc
          end
        end
      end)

    if errors == [], do: {:ok, _value}, else: {:error, errors}
  end

  def validate_schema(value, %{type: :string}) when is_binary(value), do: {:ok, value}
  def validate_schema(value, %{type: :integer}) when is_integer(value), do: {:ok, value}
  def validate_schema(value, %{type: :float}) when is_float(value), do: {:ok, value}
  def validate_schema(value, %{type: :boolean}) when is_boolean(value), do: {:ok, value}
  def validate_schema(value, %{type: :list}) when is_list(value), do: {:ok, value}
  def validate_schema(value, %{type: :map}) when is_map(value), do: {:ok, value}

  def validate_schema(_value, schema) do
    {:error, ["Value does not match expected schema type: #{inspect(schema)}"]}
  end

  # Private Functions

  defp catch_error_timeout(fun, timeout_ms) do
    timer = Process.start_timer(timeout_ms, :timeout)

    try do
      result = fun.()

      Process.cancel_timer(timer)
      {:ok, result}
    catch
      kind, reason ->
        Process.cancel_timer(timer)
        {:error, {kind, reason}}
    after
      Process.sleep(0)
    end
  rescue
    _ ->
      Process.cancel_timer(timer)
      {:error, :exception}
  end

  defp render_fixture(data) do
    """
    # Auto-generated test fixture by Lux.Testing
    # Generated at: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    defmodule Lux.Testing.Fixtures do
      @moduledoc false

      def sample_lens do
        %{
          name: "Sample Lens",
          url: "https://api.example.com/v1/sample",
          method: :get,
          schema: %{
            type: :object,
            properties: %{
              query: %{type: :string, description: "Search query"}
            },
            required: ["query"]
          }
        }
      end

      def sample_prism do
        %{
          name: "Sample Prism",
          handler: fn input, _opts -> {:ok, input} end,
          input_schema: %{
            type: :object,
            properties: %{action: %{type: :string}}
          }
        }
      end

      def sample_beam do
        %{
          name: "Sample Beam",
          steps: [
            %{type: :filter, config: %{condition: "always_true"}},
            %{type: :transform, config: %{fn: "identity"}}
          ]
        }
      end
    end
    """
  end
end

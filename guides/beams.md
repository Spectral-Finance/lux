# Beams Guide

Beams are the orchestration layer of Lux, allowing you to compose Prisms, Lenses, and other components into complex workflows. They support sequential, parallel, and conditional execution with rich error handling and logging.

## Overview

A Beam consists of:
- A sequence of steps
- Input and output schemas
- Execution configuration
- Error handling and logging
- Parameter passing between steps

## Creating a Beam

Here's a basic example of a Beam:

```elixir
defmodule MyApp.Beams.ContentProcessor do
  use Lux.Beam,
    name: "Content Processor",
    description: "Processes and enriches content",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string},
        language: %{type: :string},
        enrich: %{type: :boolean, default: true}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sentiment: %{type: :string},
        entities: %{type: :array, items: %{type: :string}},
        summary: %{type: :string}
      }
    },
    generate_execution_log: true

  @impl true
  def steps do
    sequence do
      step(:sentiment, MyApp.Prisms.SentimentAnalysis, %{
        text: :text,
        language: :language
      })

      branch {__MODULE__, :should_enrich?} do
        true ->
          parallel do
            step(:entities, MyApp.Prisms.EntityExtraction,
              %{text: :text},
              retries: 2)

            step(:summary, MyApp.Prisms.TextSummarization,
              %{text: :text, max_length: 100},
              timeout: :timer.seconds(30))
          end

        false ->
          step(:skip, MyApp.Prisms.NoOp, %{})
      end
    end
  end

  def should_enrich?(ctx) do
    Map.get(ctx.input, :enrich, true)
  end
end
```

## Step Types

### Sequential Steps
Execute steps one after another:

```elixir
sequence do
  step(:first, FirstPrism, %{param: :value})
  step(:second, SecondPrism, %{input: {:ref, "first.output"}})
  step(:third, ThirdPrism, %{data: {:ref, "second.result"}})
end
```

### Parallel Steps
Execute steps concurrently:

```elixir
parallel do
  step(:analysis, AnalysisPrism, %{data: :input})
  step(:validation, ValidationPrism, %{data: :input})
  step(:enrichment, EnrichmentPrism, %{data: :input})
end
```

### Conditional Steps
Branch based on conditions:

```elixir
branch {__MODULE__, :check_condition} do
  :path_a ->
    sequence do
      step(:a1, PathAPrism, %{})
      step(:a2, PathAPrism2, %{})
    end

  :path_b ->
    sequence do
      step(:b1, PathBPrism, %{})
      step(:b2, PathBPrism2, %{})
    end

  _ ->
    step(:default, DefaultPrism, %{})
end
```

## Parameter References

### Basic References
Reference previous step outputs:

```elixir
step(:data, DataPrism, %{value: :input_value})
step(:process, ProcessPrism, %{data: {:ref, "data.result"}})
```

### Nested References
Access nested values:

```elixir
step(:complex, ComplexPrism, %{
  value: {:ref, "data.nested.deep.value"},
  config: {:ref, "settings.options"}
})
```

### Multiple References
Combine multiple references:

```elixir
step(:combine, CombinePrism, %{
  first: {:ref, "step1.output"},
  second: {:ref, "step2.output"},
  third: {:ref, "step3.output"}
})
```

## Step Configuration

### Timeouts
```elixir
step(:long_running, LongPrism, %{},
  timeout: :timer.minutes(10))
```

### Retries
```elixir
step(:flaky, FlakyPrism, %{},
  retries: 3,
  retry_backoff: 1000)
```

### Dependencies
```elixir
step(:dependent, DependentPrism, %{},
  dependencies: ["step1", "step2"])
```

### Execution Logging
```elixir
step(:important, ImportantPrism, %{},
  store_io: true)
```

## Error Handling

### Basic Error Handling
```elixir
defmodule MyApp.Beams.RobustBeam do
  use Lux.Beam

  def steps do
    sequence do
      step(:risky, RiskyPrism, %{},
        retries: 3,
        retry_backoff: 1000,
        fallback: MyApp.Fallbacks.RiskyFallback)
    end
  end
end

defmodule MyApp.Fallbacks.RiskyFallback do
  def handle_error(%{error: error, context: ctx}) do
    case error do
      %{recoverable: true} ->
        {:continue, %{status: :degraded, result: compute_fallback(ctx)}}
      _ ->
        {:stop, "Unrecoverable error: #{inspect(error)}"}
    end
  end

  defp compute_fallback(ctx) do
    # Compute fallback result
    %{value: 0}
  end
end
```

### Inline Fallbacks
You can also define fallbacks inline using anonymous functions:

```elixir
defmodule MyApp.Beams.InlineFallbackBeam do
  use Lux.Beam

  def steps do
    sequence do
      step(:operation, OperationPrism, %{},
        fallback: fn %{error: error, context: ctx} ->
          if recoverable?(error) do
            {:continue, %{status: :degraded}}
          else
            {:stop, "Cannot proceed: #{inspect(error)}"}
          end
        end)
    end
  end
end
```

### Fallback Behavior
Fallbacks can:
- Access the error and context
- Return `{:continue, result}` to continue execution
- Return `{:stop, reason}` to halt the beam
- Transform errors into valid results
- Implement recovery strategies

### Custom Error Handling
```elixir
defmodule MyApp.Beams.ErrorHandlingBeam do
  use Lux.Beam

  def steps do
    sequence do
      step(:operation, OperationPrism, %{})
      
      branch {__MODULE__, :handle_error?} do
        :retry ->
          step(:retry, RetryPrism, %{
            original_input: {:ref, "operation.input"},
            error: {:ref, "operation.error"}
          })

        :fallback ->
          step(:fallback, FallbackPrism, %{
            error: {:ref, "operation.error"}
          })

        :fail ->
          step(:error, ErrorPrism, %{
            error: {:ref, "operation.error"},
            context: :context
          })
      end
    end
  end

  def handle_error?(ctx) do
    case ctx.operation.error do
      %{type: :temporary} -> :retry
      %{type: :permanent} -> :fallback
      _ -> :fail
    end
  end
end
```

## Best Practices

1. **Step Organization**
   - Group related steps together
   - Use meaningful step IDs
   - Keep step configurations clear
   - Document complex workflows

2. **Error Handling**
   - Use appropriate retry strategies
   - Implement fallback paths
   - Log errors with context
   - Handle all error cases

3. **Performance**
   - Use parallel execution when possible
   - Set appropriate timeouts
   - Monitor execution times

4. **Testing**
   - Test happy paths
   - Test error scenarios
   - Test parallel execution
   - Test timeouts and retries

Example test:
```elixir
defmodule MyApp.Beams.ContentProcessorTest do
  use ExUnit.Case, async: true

  describe "run/2" do
    test "processes content successfully" do
      {:ok, result, _log} = MyApp.Beams.ContentProcessor.run(%{
        text: "Great product!",
        language: "en",
        enrich: true
      })

      assert result.sentiment == "positive"
      assert length(result.entities) > 0
      assert is_binary(result.summary)
    end

    test "handles errors gracefully" do
      {:error, error, log} = MyApp.Beams.ContentProcessor.run(%{
        text: "",
        language: "invalid"
      })

      assert error.message =~ "validation failed"
      assert log.status == :failed
    end

    test "respects enrich flag" do
      {:ok, result, log} = MyApp.Beams.ContentProcessor.run(%{
        text: "Simple text",
        enrich: false
      })

      assert result.sentiment
      refute result.entities
      refute result.summary
    end
  end
end
```

## Advanced Topics

### Complex Workflows
```elixir
defmodule MyApp.Beams.ComplexWorkflow do
  use Lux.Beam,
    generate_execution_log: true

  def steps do
    sequence do
      parallel do
        step(:data1, DataSource1, %{})
        step(:data2, DataSource2, %{})
        step(:data3, DataSource3, %{})
      end

      step(:validate, DataValidator, %{
        sources: [
          {:ref, "data1"},
          {:ref, "data2"},
          {:ref, "data3"}
        ]
      })

      branch {__MODULE__, :process_path} do
        :fast ->
          step(:quick, QuickProcessor, %{
            data: {:ref, "validate"}
          })

        :thorough ->
          parallel do
            step(:analysis, DeepAnalysis, %{
              data: {:ref, "validate"}
            })

            step(:enrichment, DataEnrichment, %{
              data: {:ref, "validate"}
            })

            step(:verification, DataVerification, %{
              data: {:ref, "validate"}
            })
          end
      end

      step(:finalize, Finalizer, %{
        result: {:ref, "process_path"}
      })
    end
  end

  def process_path(ctx) do
    cond do
      ctx.validate.size > 1000 -> :thorough
      true -> :fast
    end
  end
end
```

### Dynamic Steps
```elixir
defmodule MyApp.Beams.DynamicBeam do
  use Lux.Beam

  def steps do
    sequence do
      step(:config, ConfigLoader, %{})

      branch {__MODULE__, :load_steps} do
        steps when is_list(steps) ->
          Enum.reduce(steps, {:sequence, []}, fn step, acc ->
            quote do
              unquote(acc)
              step(unquote(step.id),
                   unquote(step.module),
                   unquote(Macro.escape(step.params)))
            end
          end)
      end
    end
  end

  def load_steps(ctx) do
    ctx.config.steps
  end
end
```

### Execution Monitoring
```elixir
defmodule MyApp.Beams.MonitoredBeam do
  use Lux.Beam,
    generate_execution_log: true,
    monitoring: %{
      metrics: [:duration, :memory, :errors],
      alerts: [
        %{
          condition: &__MODULE__.alert?/1,
          action: &__MODULE__.notify/1
        }
      ]
    }

  def steps do
    sequence do
      step(:operation, MonitoredPrism, %{},
        track: true)
    end
  end

  def alert?(metrics) do
    metrics.duration > :timer.seconds(30) ||
    metrics.memory > 1_000_000_000
  end

  def notify(metrics) do
    # Send alert
  end
end
``` 
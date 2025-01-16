defmodule Lux.Engine.SubscriptionIntegrationTest do
  use ExUnit.Case, async: true
  alias Lux.Engine.{Subscription, SubscriptionRegistry}

  @limit_microseconds 10_000
  @limit_milliseconds @limit_microseconds / 1000

  setup context do
    table_name = context.test |> Atom.to_string() |> String.to_atom()
    table_ref = SubscriptionRegistry.init(table_name)
    on_exit(fn -> SubscriptionRegistry.cleanup(table_ref) end)
    {:ok, %{table: table_ref}}
  end

  describe "performance" do
    test "efficiently finds specific specters among many subscriptions", %{table: table} do
      # Create a "needle in the haystack" scenario:

      # 1. Register many subscriptions with similar but non-matching patterns
      Enum.each(1..1000, fn i ->
        # Different event types
        SubscriptionRegistry.register(
          table,
          Subscription.new(
            %{type: "other.event.#{i}", priority: "high"},
            "other_specter#{i}"
          )
        )

        # Same event type but different fields
        SubscriptionRegistry.register(
          table,
          Subscription.new(
            %{
              type: "task.created",
              priority: "low",
              category: "type#{i}",
              status: "pending"
            },
            "noise_specter#{i}"
          )
        )
      end)

      # 2. Register our target subscription in the middle of all the noise
      target_sub =
        Subscription.new(
          %{
            type: "task.created",
            priority: "high",
            category: "important",
            status: "pending"
          },
          "target_specter"
        )

      SubscriptionRegistry.register(table, target_sub)

      # 3. Add more noise after our target
      Enum.each(1001..2000, fn i ->
        SubscriptionRegistry.register(
          table,
          Subscription.new(
            %{
              type: "task.created",
              priority: "high",
              category: "other",
              status: "done"
            },
            "noise_specter#{i}"
          )
        )
      end)

      # Now test different matching scenarios with timing

      # Should find exactly our target specter within 10ms
      exact_match_signal = %{
        type: "task.created",
        priority: "high",
        category: "important",
        status: "pending",
        # Extra field shouldn't affect matching
        timestamp: "2024-01-01"
      }

      {elapsed_micros, result} =
        :timer.tc(fn ->
          SubscriptionRegistry.find_matching_specters(table, exact_match_signal)
        end)

      assert result == ["target_specter"]

      assert elapsed_micros < @limit_microseconds,
             "Query took #{elapsed_micros / 1000}ms, should be under #{@limit_milliseconds}ms"

      # Should not find our target with slightly different values
      almost_match_signal = %{
        type: "task.created",
        priority: "high",
        category: "important",
        # Different status
        status: "done"
      }

      {elapsed_micros_2, result_2} =
        :timer.tc(fn ->
          SubscriptionRegistry.find_matching_specters(table, almost_match_signal)
        end)

      refute "target_specter" in result_2

      assert elapsed_micros_2 < @limit_microseconds,
             "Query took #{elapsed_micros_2 / 1000}ms, should be under #{@limit_milliseconds}ms"

      # Should find nothing for completely different event type
      different_signal = %{
        type: "task.deleted",
        priority: "high",
        category: "important"
      }

      {elapsed_micros_3, result_3} =
        :timer.tc(fn ->
          SubscriptionRegistry.find_matching_specters(table, different_signal)
        end)

      assert result_3 == []

      assert elapsed_micros_3 < @limit_microseconds,
             "Query took #{elapsed_micros_3 / 1000}ms, should be under #{@limit_milliseconds}ms"
    end

    test "handles concurrent registrations and queries", %{table: table} do
      # Start 10 concurrent processes registering subscriptions
      registration_tasks =
        for i <- 1..10 do
          Task.async(fn ->
            Enum.each(1..100, fn j ->
              SubscriptionRegistry.register(
                table,
                Subscription.new(
                  %{type: "test.event.#{i}", priority: "high", index: j},
                  "specter_#{i}_#{j}"
                )
              )
            end)
          end)
        end

      # Start 5 concurrent processes querying while registration is happening
      query_tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            Enum.map(1..20, fn i ->
              signal = %{type: "test.event.#{rem(i, 10) + 1}", priority: "high"}

              {elapsed_micros, result} =
                :timer.tc(fn ->
                  SubscriptionRegistry.find_matching_specters(table, signal)
                end)

              {elapsed_micros, length(result)}
            end)
          end)
        end

      # Wait for all tasks to complete
      Task.await_many(registration_tasks)
      query_results = Task.await_many(query_tasks)

      # Verify all queries completed within time limit
      Enum.each(List.flatten(query_results), fn {elapsed_micros, _count} ->
        assert elapsed_micros < @limit_microseconds,
               "Query took #{elapsed_micros / 1000}ms, should be under #{@limit_milliseconds}ms"
      end)
    end
  end
end

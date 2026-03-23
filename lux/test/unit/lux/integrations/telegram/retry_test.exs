defmodule Lux.Integrations.Telegram.RetryTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Retry

  @moduletag :unit

  describe "with_retry/2" do
    test "returns success immediately without retrying" do
      result = Retry.with_retry(fn -> {:ok, "success"} end)
      assert result == {:ok, "success"}
    end

    test "does not retry 400 client errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, {400, "Bad Request"}}
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:error, {400, "Bad Request"}}
      assert :counters.get(counter, 1) == 1
    end

    test "does not retry 401 unauthorized errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, :invalid_token}
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:error, :invalid_token}
      assert :counters.get(counter, 1) == 1
    end

    test "does not retry 403 forbidden errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, {403, "Forbidden"}}
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:error, {403, "Forbidden"}}
      assert :counters.get(counter, 1) == 1
    end

    test "does not retry 404 not found errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, {404, "Not Found"}}
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:error, {404, "Not Found"}}
      assert :counters.get(counter, 1) == 1
    end

    test "retries on 500 server errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            count = :counters.get(counter, 1) + 1
            :counters.put(counter, 1, count)

            if count < 3 do
              {:error, {500, "Internal Server Error"}}
            else
              {:ok, "recovered"}
            end
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:ok, "recovered"}
      assert :counters.get(counter, 1) == 3
    end

    test "retries on 502 bad gateway errors" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            count = :counters.get(counter, 1) + 1
            :counters.put(counter, 1, count)

            if count < 2 do
              {:error, {502, "Bad Gateway"}}
            else
              {:ok, "recovered"}
            end
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:ok, "recovered"}
      assert :counters.get(counter, 1) == 2
    end

    test "gives up after max_retries" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, {500, "Internal Server Error"}}
          end,
          max_retries: 2, base_delay: 1
        )

      assert result == {:error, {500, "Internal Server Error"}}
      # 1 initial + 2 retries = 3 attempts
      assert :counters.get(counter, 1) == 3
    end

    test "respects max_retries option" do
      counter = :counters.new(1, [:atomics])

      Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          {:error, {503, "Service Unavailable"}}
        end,
        max_retries: 1, base_delay: 1
      )

      # 1 initial + 1 retry = 2 attempts
      assert :counters.get(counter, 1) == 2
    end

    test "handles 429 with retry_after in response" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            count = :counters.get(counter, 1) + 1
            :counters.put(counter, 1, count)

            if count < 2 do
              {:error, {429, %{"retry_after" => 1, "description" => "Too Many Requests"}}}
            else
              {:ok, "recovered"}
            end
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:ok, "recovered"}
      assert :counters.get(counter, 1) == 2
    end

    test "handles 429 with parameters.retry_after in response" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            count = :counters.get(counter, 1) + 1
            :counters.put(counter, 1, count)

            if count < 2 do
              {:error, {429, %{"parameters" => %{"retry_after" => 1}}}}
            else
              {:ok, "recovered"}
            end
          end,
          max_retries: 3, base_delay: 1
        )

      assert result == {:ok, "recovered"}
      assert :counters.get(counter, 1) == 2
    end
  end
end

defmodule Lux.Integrations.RateLimitMiddlewareTest do
  use UnitAPICase, async: true

  alias Lux.Telegram.Middleware.RateLimit
  alias Lux.Telegram.Middleware.Retry

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Lux.Telegram.Middleware.RateLimit" do
    test "extracts retry_after from string keys in body" do
      response = %Req.Response{
        status: 429,
        body: %{"parameters" => %{"retry_after" => 5}}
      }

      assert RateLimit.extract_retry_after(response) == 5
    end

    test "extracts retry_after from atom keys in body" do
      response = %Req.Response{
        status: 429,
        body: %{parameters: %{retry_after: 8}}
      }

      assert RateLimit.extract_retry_after(response) == 8
    end

    test "extracts retry_after from string binary in parameters" do
      response = %Req.Response{
        status: 429,
        body: %{"parameters" => %{"retry_after" => "15"}}
      }

      assert RateLimit.extract_retry_after(response) == 15
    end

    test "extracts retry_after from float and rounds/truncates to integer" do
      response = %Req.Response{
        status: 429,
        body: %{"parameters" => %{"retry_after" => 4.8}}
      }

      assert RateLimit.extract_retry_after(response) == 4
    end

    test "clamps negative and zero retry_after values to 1 second" do
      response_zero = %Req.Response{
        status: 429,
        body: %{"parameters" => %{"retry_after" => 0}}
      }

      response_neg = %Req.Response{
        status: 429,
        body: %{"parameters" => %{"retry_after" => -10}}
      }

      assert RateLimit.extract_retry_after(response_zero) == 1
      assert RateLimit.extract_retry_after(response_neg) == 1
    end

    test "extracts retry_after from Retry-After header with case-insensitivity" do
      response_list = %Req.Response{
        status: 429,
        headers: %{"retry-after" => ["12"]},
        body: %{}
      }

      response_mixed = %Req.Response{
        status: 429,
        headers: [{"Retry-After", "25"}, :invalid_header_item],
        body: %{}
      }

      response_float_header = %Req.Response{
        status: 429,
        headers: [{"retry-after", "4.2"}],
        body: %{}
      }

      assert RateLimit.extract_retry_after(response_list) == 12
      assert RateLimit.extract_retry_after(response_mixed) == 25
      assert RateLimit.extract_retry_after(response_float_header) == 4
    end

    test "defaults to 1 second when parameters and headers are missing or invalid" do
      response_empty = %Req.Response{
        status: 429,
        headers: [],
        body: %{"description" => "Too many requests"}
      }

      assert RateLimit.extract_retry_after(response_empty) == 1
    end


    test "retries request on HTTP 429 status code up to max_rate_limit_retries with sleep_fun" do
      test_process = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        count = Agent.get_and_update(counter, fn c -> {c + 1, c + 1} end)
        send(test_process, {:attempt, count})

        if count > 1 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => "success"}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(429, Jason.encode!(%{
            "ok" => false,
            "error_code" => 429,
            "parameters" => %{"retry_after" => 2}
          }))
        end
      end)

      {:ok, response} =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          max_rate_limit_retries: 2
        })

      assert response["ok"] == true
      assert response["result"] == "success"
      assert_received {:attempt, 1}
      assert_received {:slept, 2000}
      assert_received {:attempt, 2}
    end

    test "exhausts retries and returns final 429 response when max_rate_limit_retries is reached" do
      test_process = self()

      Req.Test.expect(TelegramClientMock, 3, fn conn ->
        send(test_process, :attempt)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests",
          "parameters" => %{"retry_after" => 1}
        }))
      end)

      result =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          max_rate_limit_retries: 2
        })

      assert {:error, {429, %{"parameters" => %{"retry_after" => 1}}}} = result
      assert_received :attempt
      assert_received {:slept, 1000}
      assert_received :attempt
      assert_received {:slept, 1000}
      assert_received :attempt
      refute_received :attempt
    end

    test "does not retry when max_rate_limit_retries is 0" do
      test_process = self()

      Req.Test.expect(TelegramClientMock, 1, fn conn ->
        send(test_process, :attempt)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests",
          "parameters" => %{"retry_after" => 5}
        }))
      end)

      result =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          max_rate_limit_retries: 0
        })

      assert {:error, {429, %{"parameters" => %{"retry_after" => 5}}}} = result
      assert_received :attempt
      refute_received {:slept, _}
    end
  end

  describe "Lux.Telegram.Middleware.Retry" do
    test "identifies retryable responses and errors" do
      assert Retry.retryable?(%Req.Response{status: 500}) == true
      assert Retry.retryable?(%Req.Response{status: 502}) == true
      assert Retry.retryable?(%Req.Response{status: 503}) == true
      assert Retry.retryable?(%Req.Response{status: 504}) == true
      assert Retry.retryable?(%Req.Response{status: 200}) == false
      assert Retry.retryable?(%Req.Response{status: 400}) == false
      assert Retry.retryable?(%Req.Response{status: 404}) == false
      assert Retry.retryable?(%Req.Response{status: 422}) == false
      assert Retry.retryable?(%Req.TransportError{reason: :econnrefused}) == true
      assert Retry.retryable?(%Req.TransportError{reason: :timeout}) == true
      assert Retry.retryable?(%RuntimeError{message: "network issue"}) == true
      assert Retry.retryable?({:error, %Req.TransportError{reason: :econnrefused}}) == true
      assert Retry.retryable?({:error, :econnrefused}) == true
    end

    test "calculates exponential backoff delay correctly and caps at max_backoff" do
      assert Retry.calculate_backoff(100, 2, 0, 5000) == 100
      assert Retry.calculate_backoff(100, 2, 1, 5000) == 200
      assert Retry.calculate_backoff(100, 2, 2, 5000) == 400
      assert Retry.calculate_backoff(100, 2, 3, 5000) == 800
      assert Retry.calculate_backoff(100, 2, 10, 5000) == 5000

      # Custom base and factor
      assert Retry.calculate_backoff(50, 3, 0, 1000) == 50
      assert Retry.calculate_backoff(50, 3, 1, 1000) == 150
      assert Retry.calculate_backoff(50, 3, 2, 1000) == 450
      assert Retry.calculate_backoff(50, 3, 3, 1000) == 1000
    end

    test "retries request on HTTP 5xx status code with exponential backoff progression" do
      test_process = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.expect(TelegramClientMock, 3, fn conn ->
        count = Agent.get_and_update(counter, fn c -> {c + 1, c + 1} end)
        send(test_process, {:attempt, count})

        if count >= 3 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => "recovered"}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(502, Jason.encode!(%{
            "ok" => false,
            "description" => "Bad Gateway attempt #{count}"
          }))
        end
      end)

      {:ok, response} =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          base_backoff: 50,
          backoff_factor: 2,
          max_retries: 3
        })

      assert response["ok"] == true
      assert response["result"] == "recovered"
      assert_received {:attempt, 1}
      assert_received {:slept, 50}
      assert_received {:attempt, 2}
      assert_received {:slept, 100}
      assert_received {:attempt, 3}
    end

    test "exhausts retries on persistent 5xx and returns error tuple" do
      test_process = self()

      Req.Test.expect(TelegramClientMock, 3, fn conn ->
        send(test_process, :attempt)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{
          "ok" => false,
          "description" => "Internal Server Error"
        }))
      end)

      result =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          base_backoff: 100,
          max_retries: 2
        })

      assert {:error, {500, "Internal Server Error"}} = result
      assert_received :attempt
      assert_received {:slept, 100}
      assert_received :attempt
      assert_received {:slept, 200}
      assert_received :attempt
      refute_received :attempt
    end

    test "does not retry 5xx when max_retries is 0" do
      test_process = self()

      Req.Test.expect(TelegramClientMock, 1, fn conn ->
        send(test_process, :attempt)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{
          "ok" => false,
          "description" => "Service Unavailable"
        }))
      end)

      result =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          max_retries: 0
        })

      assert {:error, {503, "Service Unavailable"}} = result
      assert_received :attempt
      refute_received {:slept, _}
    end

    test "retries transport errors and recovers on subsequent attempt" do
      test_process = self()

      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        attempt =
          case Process.get(:test_transport_attempt, 1) do
            1 ->
              Process.put(:test_transport_attempt, 2)
              1

            2 ->
              2
          end

        send(test_process, {:attempt, attempt})

        if attempt == 1 do
          Req.Test.transport_error(conn, :closed)
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "ok" => true,
            "result" => "recovered_from_transport"
          }))
        end
      end)

      {:ok, response} =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          base_backoff: 50,
          backoff_factor: 2,
          max_retries: 3
        })

      assert response["ok"] == true
      assert response["result"] == "recovered_from_transport"
      assert_received {:attempt, 1}
      assert_received {:slept, 50}
      assert_received {:attempt, 2}
    end

    test "wrap_adapter safely catches synchronous exceptions from plug/adapter and retries" do
      test_process = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      plug = fn conn ->
        attempt = Agent.get_and_update(counter, fn c -> {c + 1, c + 1} end)
        send(test_process, {:attempt, attempt})

        if attempt == 1 do
          raise Req.TransportError, reason: :timeout
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "ok" => true,
            "result" => "recovered_from_exception"
          }))
        end
      end

      {:ok, response} =
        Lux.Integrations.Telegram.Client.request(:get, "/getMe", %{
          token: "test_token",
          plug: plug,
          sleep_fun: fn ms -> send(test_process, {:slept, ms}) end,
          base_backoff: 50,
          backoff_factor: 2,
          max_retries: 3
        })

      assert response["ok"] == true
      assert response["result"] == "recovered_from_exception"
      assert_received {:attempt, 1}
      assert_received {:slept, 50}
      assert_received {:attempt, 2}
    end
  end

  describe "RateLimit and Retry middleware direct unit tests & edge cases" do
    test "RateLimit.attach/2 with default arguments and map options" do
      req1 = RateLimit.attach(Req.new())
      assert req1.options[:max_rate_limit_retries] == nil

      req2 = RateLimit.attach(Req.new(), %{max_rate_limit_retries: 5})
      assert req2.options[:max_rate_limit_retries] == 5
    end

    test "RateLimit.extract_retry_after from maps, scalars, and float strings" do
      assert RateLimit.extract_retry_after(%{"parameters" => %{"retry_after" => 6}}) == 6
      assert RateLimit.extract_retry_after(%{"retry_after" => 7}) == 7
      assert RateLimit.extract_retry_after(%{retry_after: 8}) == 8
      assert RateLimit.extract_retry_after(%{}) == 1
      assert RateLimit.extract_retry_after(:invalid_atom) == 1
      assert RateLimit.extract_retry_after(nil) == 1

      resp_non_map_body = %Req.Response{status: 429, body: "not a map"}
      assert RateLimit.extract_retry_after(resp_non_map_body) == 1

      resp_nil_headers = %Req.Response{status: 429, body: nil, headers: nil}
      assert RateLimit.extract_retry_after(resp_nil_headers) == 1

      resp_float = %Req.Response{status: 429, body: %{"parameters" => %{"retry_after" => "5.7"}}}
      assert RateLimit.extract_retry_after(resp_float) == 5

      resp_atom_val = %Req.Response{status: 429, body: %{"parameters" => %{"retry_after" => :atom_val}}}
      assert RateLimit.extract_retry_after(resp_atom_val) == 1

      resp_invalid = %Req.Response{status: 429, body: %{"parameters" => %{"retry_after" => "not_a_number"}}}
      assert RateLimit.extract_retry_after(resp_invalid) == 1

      resp_headers = %Req.Response{
        status: 429,
        headers: [{"X-Server", "Telegram"}, {"other-header", "foo"}, {"Retry-After", "19"}],
        body: %{}
      }
      assert RateLimit.extract_retry_after(resp_headers) == 19
    end

    test "Retry.attach/2 with default arguments and map options" do
      req1 = Retry.attach(Req.new())
      assert req1.options[:max_retries] == nil

      req2 = Retry.attach(Req.new(), %{max_retries: 4, base_backoff: 250})
      assert req2.options[:max_retries] == 4
      assert req2.options[:base_backoff] == 250
    end

    test "Retry.retryable?/1 classification for exceptions and non-retryables" do
      assert Retry.retryable?({:error, %RuntimeError{message: "crash"}}) == true
      assert Retry.retryable?(:ok) == false
      assert Retry.retryable?({:error, :unknown_error}) == false
      assert Retry.retryable?(%Req.Response{status: 400}) == false
    end

    test "Retry.calculate_backoff handles invalid and negative options gracefully" do
      assert Retry.calculate_backoff(-100, -1, -5, -5000) == 100
    end

    defmodule TestMFAAdapter do
      def call(request, extra) do
        {request, %Req.Response{status: 200, body: extra}}
      end
    end

    test "Retry.wrap_adapter safely wraps MFA adapter, invalid adapter, and catches throws" do
      # MFA adapter
      mfa_req = Req.new(adapter: {TestMFAAdapter, :call, ["mfa_val"]}) |> Retry.wrap_adapter()
      assert {_, %Req.Response{body: "mfa_val"}} = mfa_req.adapter.(mfa_req)

      # Invalid adapter
      bad_req = Req.new(adapter: 12345) |> Retry.wrap_adapter()
      assert {_, %RuntimeError{message: msg}} = bad_req.adapter.(bad_req)
      assert msg =~ "expected adapter to be 1-arity function or MFA"

      # Throw catch
      throw_req = Req.new(adapter: fn _req -> throw(:custom_throw_val) end) |> Retry.wrap_adapter()
      assert {_, %Req.TransportError{reason: {:throw, :custom_throw_val}}} = throw_req.adapter.(throw_req)
    end
  end
end

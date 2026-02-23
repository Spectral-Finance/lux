defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "online_model?/1" do
    test "returns true for sonar models" do
      assert Perplexity.online_model?("sonar")
      assert Perplexity.online_model?("sonar-pro")
      assert Perplexity.online_model?("sonar-reasoning")
      assert Perplexity.online_model?("sonar-reasoning-pro")
    end

    test "returns false for offline models" do
      refute Perplexity.online_model?("sonar-chat")
      refute Perplexity.online_model?("r1-1776")
      refute Perplexity.online_model?("unknown-model")
    end
  end

  describe "valid_recency_filter?/1" do
    test "returns true for valid filters" do
      assert Perplexity.valid_recency_filter?("month")
      assert Perplexity.valid_recency_filter?("week")
      assert Perplexity.valid_recency_filter?("day")
      assert Perplexity.valid_recency_filter?("hour")
    end

    test "returns false for invalid filters" do
      refute Perplexity.valid_recency_filter?("year")
      refute Perplexity.valid_recency_filter?("minute")
      refute Perplexity.valid_recency_filter?("")
    end
  end

  describe "online_models/0" do
    test "returns list of online model names" do
      models = Perplexity.online_models()
      assert is_list(models)
      assert "sonar" in models
      assert "sonar-pro" in models
    end
  end

  describe "call/3" do
    test "makes correct API call to Perplexity endpoint" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar",
        json_response: false
      }

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer pplx-test-key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar"
        assert [%{"role" => "user", "content" => "What is Solana?"}] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "id" => "pplx-test-123",
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  "Solana is a high-performance blockchain platform known for its speed and low transaction costs."
              },
              "finish_reason" => "stop"
            }
          ],
          "citations" => [
            "https://solana.com",
            "https://docs.solana.com"
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 25,
            "total_tokens" => 35
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"text" => "Solana is a high-performance blockchain platform" <> _},
                  model: "sonar",
                  finish_reason: "stop",
                  citations: ["https://solana.com", "https://docs.solana.com"]
                }
              }} = Perplexity.call("What is Solana?", [], config)
    end

    test "handles response without citations (offline model)" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar-chat",
        json_response: false
      }

      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "model" => "sonar-chat",
          "choices" => [
            %{
              "message" => %{"content" => "Hello, how can I help?"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"total_tokens" => 12}
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  citations: [],
                  content: %{"text" => "Hello, how can I help?"}
                }
              }} = Perplexity.call("Hi", [], config)
    end

    test "passes search domain filter" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar",
        json_response: false,
        search_domain_filter: ["docs.solana.com", "solana.com"]
      }

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["search_domain_filter"] == ["docs.solana.com", "solana.com"]

        Req.Test.json(conn, %{
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{"content" => "Filtered result"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{}} = Perplexity.call("Solana docs", [], config)
    end

    test "passes recency filter for time-sensitive queries" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar",
        json_response: false,
        search_recency_filter: "week"
      }

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["search_recency_filter"] == "week"

        Req.Test.json(conn, %{
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{"content" => "This week's news..."},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{}} = Perplexity.call("Latest crypto news", [], config)
    end

    test "parses JSON response when json_response is true" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar",
        json_response: true
      }

      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"price": 150.5, "change_24h": 2.3})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"price" => 150.5, "change_24h" => 2.3}
                }
              }} = Perplexity.call("What is ETH price?", [], config)
    end

    test "returns error on invalid API key" do
      config = %{api_key: "invalid-key", model: "sonar"}

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} = Perplexity.call("test", [], config)
    end

    test "returns error on rate limit" do
      config = %{api_key: "pplx-test-key", model: "sonar-pro"}

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Rate limit exceeded"}})
      end)

      assert {:error, :rate_limited} = Perplexity.call("test", [], config)
    end

    test "uses sonar as default model when none configured" do
      config = %{api_key: "pplx-test-key"}

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar"

        Req.Test.json(conn, %{
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{"content" => "Default model response"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{payload: %{model: "sonar"}}} =
               Perplexity.call("test", [], config)
    end

    test "passes return_images option" do
      config = %{
        api_key: "pplx-test-key",
        model: "sonar",
        json_response: false,
        return_images: true
      }

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["return_images"] == true

        Req.Test.json(conn, %{
          "model" => "sonar",
          "choices" => [
            %{
              "message" => %{"content" => "Response with images"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{}} = Perplexity.call("Show me images of Solana", [], config)
    end
  end
end

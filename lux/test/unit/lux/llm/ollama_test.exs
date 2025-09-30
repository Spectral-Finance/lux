defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.{ModelManager, ResourcePool}

  setup do
    Req.Test.verify_on_exit!()

    if :ets.whereis(ModelManager) != :undefined do
      :ets.delete_all_objects(ModelManager)
    end

    Application.put_env(:lux, Ollama, [])

    :ok
  end

  describe "call/3" do
    test "uses cached model metadata and sends chat request" do
      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [%{"name" => "llama3", "digest" => "abc"}]
        })
      end)

      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/chat"

        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3"
        assert [%{"role" => "user", "content" => "Hello"}] = decoded["messages"]

        Req.Test.json(conn, %{
          "model" => "llama3",
          "message" => %{"content" => ~s({"answer":"hi"})},
          "done" => true,
          "metrics" => %{"input_tokens" => 2, "output_tokens" => 3}
        })
      end)

      assert {:ok, signal} = Ollama.call("Hello", [], %{})
      assert signal.payload.content == %{"answer" => "hi"}
      assert signal.payload.model == "llama3"

      # second call should use cache (no new /api/tags request)
      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/chat"
        Req.Test.json(conn, %{
          "model" => "llama3",
          "message" => %{"content" => "hi"},
          "done" => true
        })
      end)

      assert {:ok, _signal} = Ollama.call("Hello", [], %{})
    end

    test "auto pulls model when missing" do
      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/tags"
        Req.Test.json(conn, %{"models" => []})
      end)

      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/pull"
        {:ok, body, _} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"model" => "custom"}

        Req.Test.json(conn, %{"status" => "success", "digest" => "xyz"})
      end)

      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/chat"
        Req.Test.json(conn, %{
          "model" => "custom",
          "message" => %{"content" => "response"},
          "done" => true
        })
      end)

      assert {:ok, _signal} =
               Ollama.call("Prompt", [], %{model: "custom", auto_pull: true})
    end

    test "returns error when pool busy" do
      now = System.monotonic_time(:millisecond)
      :ets.insert(ModelManager, {"llama3", %{model: "llama3", digest: "cached", size: nil, pulled_at: now, last_used_at: now, ttl: :timer.minutes(5)}})

      assert :ok == ResourcePool.checkout()
      assert :ok == ResourcePool.checkout()

      on_exit(fn ->
        ResourcePool.checkin()
        ResourcePool.checkin()
      end)

      assert {:error, :busy} = Ollama.call("two", [], %{})
    end
  end

  describe "ModelManager" do
    test "cached_models/0 returns inserted metadata" do
      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/tags"
        Req.Test.json(conn, %{"models" => [%{"name" => "llama3", "digest" => "abc", "size" => 123}]})
      end)

      Req.Test.expect(Ollama.Client, fn conn ->
        assert conn.request_path == "/api/chat"
        Req.Test.json(conn, %{"model" => "llama3", "message" => %{"content" => "hi"}, "done" => true})
      end)

      assert {:ok, _signal} = Ollama.call("hi", [], %{})

      assert [%{model: "llama3", digest: "abc"}] =
               ModelManager.cached_models()
               |> Enum.map(&Map.take(&1, [:model, :digest]))
    end
  end
end

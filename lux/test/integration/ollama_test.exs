defmodule Lux.Integration.LLM.OllamaTest do
  use IntegrationCase, async: false

  import Plug.Conn

  alias Bypass
  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.ModelManager

  setup do
    {:ok, counter} = Agent.start_link(fn -> %{tags: 0, pull: 0, chat: 0} end)
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/api/tags"} ->
          Agent.update(counter, fn state -> Map.update(state, :tags, 1, &(&1 + 1)) end)

          response =
            case Agent.get(counter, & &1[:tags]) do
              1 -> %{models: []}
              _ -> %{models: [%{"name" => "integration-model"}]}
            end

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(response))

        {"POST", "/api/pull"} ->
          Agent.update(counter, fn state -> Map.update(state, :pull, 1, &(&1 + 1)) end)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{"status" => "success"}))

        {"POST", "/api/chat"} ->
          Agent.update(counter, fn state -> Map.update(state, :chat, 1, &(&1 + 1)) end)
          {:ok, body, conn} = read_body(conn)
          params = Jason.decode!(body)

          response = %{
            "model" => params["model"],
            "message" => %{"content" => ~s({"answer":"hello"})},
            "done" => true,
            "metrics" => %{"input_tokens" => 3, "output_tokens" => 2}
          }

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(response))
      end
    end)

    if :ets.whereis(ModelManager) != :undefined do
      :ets.delete_all_objects(ModelManager)
    end

    :telemetry.attach(
      "ollama-integration-test",
      [:lux, :ollama, :request, :stop],
      fn _event, measurements, metadata, _ ->
        send(self(), {:telemetry, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach("ollama-integration-test")
      Bypass.down(bypass)
    end)

    {:ok, bypass: bypass, counter: counter}
  end

  test "performs full request lifecycle", %{bypass: bypass, counter: counter} do
    endpoint = "http://127.0.0.1:#{bypass.port}"

    config = %{
      endpoint: endpoint,
      model: "integration-model",
      auto_pull: true,
      telemetry_metadata: %{request_id: "integration"}
    }

    assert {:ok, signal} = Ollama.call("Hello integration", [], config)
    assert signal.payload.content == %{"answer" => "hello"}
    assert signal.payload.model == "integration-model"

    counts = Agent.get(counter, & &1)
    assert counts[:pull] == 1
    assert counts[:chat] == 1
    assert counts[:tags] >= 1

    assert [%{model: "integration-model"} | _] = ModelManager.cached_models()

    assert_receive {:telemetry, %{status: :ok}, metadata}
    assert metadata.model == "integration-model"
    assert metadata.request_id == "integration"
  end
end

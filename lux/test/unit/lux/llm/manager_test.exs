defmodule Lux.LLM.ManagerTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Manager
  alias Lux.LLM.Manager.Server
  alias Lux.LLM.OpenAI
  alias Lux.LLM.Anthropic
  alias Lux.Signal

  defmodule TestProvider1 do
    @behaviour Lux.LLM
    def call(_prompt, _tools, _config) do
      {:error, "provider 1 failed"}
    end
  end

  defmodule TestProvider2 do
    @behaviour Lux.LLM
    def call(_prompt, _tools, _config) do
      {:ok, %Lux.Signal{payload: %{content: "provider 2 succeeded"}}}
    end
  end

  setup do
    # Clear cache and metrics in GenServer
    GenServer.call(Server, :clear)
    :ok
  end

  describe "resolve_providers/1" do
    test "returns custom providers if specified" do
      config = %{providers: [MyCustomProvider]}
      assert [MyCustomProvider] == Manager.resolve_providers(config)
    end

    test "selects OpenAI for gpt models" do
      config = %{model: "gpt-4"}
      providers = Manager.resolve_providers(config)
      assert hd(providers) == OpenAI
    end

    test "selects Anthropic for claude models" do
      config = %{model: "claude-3-opus"}
      providers = Manager.resolve_providers(config)
      assert hd(providers) == Anthropic
    end
  end

  describe "call/3" do
    test "calls preferred provider successfully" do
      Req.Test.expect(OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4",
          "choices" => [%{"message" => %{"content" => ~s({"result": "openai response"})}, "finish_reason" => "stop"}]
        })
      end)

      config = %{model: "gpt-4", cache: false}
      assert {:ok, %Signal{payload: %{content: %{"result" => "openai response"}}}} = Manager.call("hello", [], config)
    end

    test "falls back to next provider if preferred provider fails" do
      # We customize the provider chain for test speed and reliability
      config = %{providers: [TestProvider1, TestProvider2], cache: false}
      assert {:ok, %Signal{payload: %{content: "provider 2 succeeded"}}} = Manager.call("hello", [], config)
    end

    test "caches successful responses" do
      Req.Test.expect(OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4",
          "choices" => [%{"message" => %{"content" => ~s({"result": "cacheable response"})}, "finish_reason" => "stop"}]
        })
      end)

      config = %{providers: [OpenAI], cache: true}
      
      # First call hits mock
      assert {:ok, %Signal{payload: %{content: %{"result" => "cacheable response"}}}} = Manager.call("hello cached", [], config)
      
      # Second call hits cache (no mock expectation set, so it would fail if it called mock)
      assert {:ok, %Signal{payload: %{content: %{"result" => "cacheable response"}}}} = Manager.call("hello cached", [], config)
    end

    test "records metrics on GenServer" do
      Req.Test.expect(OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "model" => "gpt-4",
          "choices" => [%{"message" => %{"content" => ~s({"result": "success response"})}, "finish_reason" => "stop"}]
        })
      end)

      config = %{providers: [OpenAI], cache: false}
      assert {:ok, _} = Manager.call("hello metrics", [], config)

      metrics = GenServer.call(Server, :get_metrics)
      assert %{success: 1, failure: 0} = Map.get(metrics, OpenAI)
    end
  end
end

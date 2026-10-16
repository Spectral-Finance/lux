defmodule Lux.LLM.GatewayTest do
  use UnitAPICase, async: false

  alias Lux.LLM.CircuitBreaker
  alias Lux.LLM.Cost
  alias Lux.LLM.Gateway
  alias Lux.LLM.Registry
  alias Lux.LLM.Stats

  defmodule ConfigDrivenProvider do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :config_driven,
        models: [
          %{id: "cd-mini", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
            max_context: 200_000, capabilities: [:tools]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, config) do
      Process.put(:gateway_test_last_config, config)
      {:ok, %Lux.LLM.Response{content: "ok"}}
    end
  end

  setup do
    start_supervised!(Registry)
    start_supervised!(Cost)
    start_supervised!(Stats)
    start_supervised!({CircuitBreaker, failure_threshold: 1})

    Application.put_env(:lux, Gateway,
      default_requirements: %{prompt_tokens: 2_000},
      register: [{ConfigDrivenProvider, %{model: "cd-mini"}}]
    )

    on_exit(fn ->
      Application.delete_env(:lux, Gateway)
      Application.delete_env(:lux, Cost)
    end)

    :ok
  end

  describe "register_configured_providers/0" do
    test "registers the providers listed in config with their options" do
      :ok = Gateway.register_configured_providers()

      assert entry = Registry.lookup(ConfigDrivenProvider)
      assert entry.default_model == "cd-mini"
    end
  end

  describe "call/3" do
    test "routes through the router with merged requirements" do
      :ok = Gateway.register_configured_providers()

      assert {:ok, _} = Gateway.call("hello", [], quality: :cheap)

      assert %{model: "cd-mini"} = Process.get(:gateway_test_last_config)
    end

    test "explicit requirements win over configured defaults" do
      :ok = Gateway.register_configured_providers()

      assert {:ok, _} =
               Gateway.call("hello", [], requirements: [prompt_tokens: 3_000, quality: :best])
    end
  end
end

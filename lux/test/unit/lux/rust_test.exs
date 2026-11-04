defmodule Lux.RustTest do
  use ExUnit.Case, async: false

  require Lux.Rust
  import Lux.Rust, only: [sigil_RS: 2, rust: 2]

  alias Lux.Rust

  setup do
    Rust.reset!()
    :ok
  end

  describe "Rust component definition and trait integration" do
    test "defines a Rust prism component with traits and converts it to a Lux.Prism" do
      {:ok, comp} =
        Rust.define_component(:fast_OrderbookPrism,
          name: "Fast Orderbook Prism",
          kind: :prism,
          traits: [:prism, :async_executor, :zero_copy],
          input_schema: %{type: :object, properties: %{symbol: %{type: :string}}},
          source: ~RS"""
          pub async fn handle(input: Value) -> Result<Value, String> {
              Ok(input)
          }
          """
        )

      assert comp.id == :fast_OrderbookPrism
      assert comp.kind == :prism
      assert comp.async == true
      assert comp.status == :initialized
      assert :zero_copy in comp.traits

      assert {:ok, prism} = Rust.to_prism(comp)
      assert prism.name == "Fast Orderbook Prism"
      assert {:ok, exec_res} = prism.handler.(%{symbol: "ETH-USDC"}, %{name: "TraderAgent"})
      assert exec_res.executed == true
      assert exec_res.input == %{symbol: "ETH-USDC"}
    end

    test "rejects unsupported traits" do
      assert {:error, {:unsupported_rust_traits, [:unknown_trait]}} =
               Rust.define_component(:bad_comp,
                 kind: :prism,
                 traits: [:unknown_trait],
                 source: "pub fn main() {}"
               )
    end
  end

  describe "async/await execution and artifact caching" do
    test "executes Rust component asynchronously via eval_async/2 and caches artifact" do
      {:ok, _comp} =
        Rust.define_component(:async_beam_step,
          kind: :beam,
          traits: [:beam, :async_executor],
          source: ~RS"""
          pub async fn execute_step(payload: Value) -> Result<Value, String> {
              Ok(payload)
          }
          """
        )

      task = Rust.eval_async(:async_beam_step, variables: %{step: 1, tvl: 500_000})
      assert {:ok, result} = Rust.await_result(task)
      assert result.component_id == :async_beam_step
      assert result.async == true

      # Inline macro evaluation with artifact cache hit on second call
      assert {:ok, first_eval} =
               (rust variables: %{x: 10} do
                  ~RS"""
                  pub async fn compute(x: i64) -> i64 { x * 2 }
                  """
                end)

      assert first_eval.cache_hit == false

      assert {:ok, second_eval} =
               (rust variables: %{x: 20} do
                  ~RS"""
                  pub async fn compute(x: i64) -> i64 { x * 2 }
                  """
                end)

      assert second_eval.cache_hit == true
      assert Rust.cache_stats().cached_artifacts >= 2
    end
  end

  describe "component lifecycle management" do
    test "manages component state transitions through termination" do
      {:ok, _} =
        Rust.define_component(:stateful_prism,
          kind: :prism,
          traits: [:prism, :stateful_lifecycle],
          source: "pub fn handle() {}"
        )

      assert {:ok, terminated} = Rust.terminate_component(:stateful_prism)
      assert terminated.status == :stopped

      assert {:error, {:component_not_active, :stopped}} =
               Rust.execute_component(:stateful_prism, %{})
    end
  end
end

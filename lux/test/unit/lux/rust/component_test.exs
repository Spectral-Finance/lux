defmodule Lux.Rust.ComponentTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Component

  describe "traits/0" do
    test "provides async trait definitions for Prisms and Beams" do
      traits = Component.traits()

      assert String.contains?(traits, "pub trait LuxPrism: Send + Sync")
      assert String.contains?(traits, "pub trait LuxBeam: Send + Sync")
      assert String.contains?(traits, "async fn handler(&self, input: Value)")
      assert String.contains?(traits, "async fn run(&self, initial_state: Value)")
      assert String.contains?(traits, "pub enum ComponentState")
    end
  end

  describe "generate_prism/3" do
    test "generates a valid Rust Prism implementation" do
      code = Component.generate_prism("SentimentAnalysisPrism", "Analyzes text sentiment", version: "1.2.0")

      assert String.contains?(code, "pub struct SentimentAnalysisPrism;")
      assert String.contains?(code, "impl LuxPrism for SentimentAnalysisPrism")
      assert String.contains?(code, "name: \"SentimentAnalysisPrism\".to_string()")
      assert String.contains?(code, "version: \"1.2.0\".to_string()")
    end
  end

  describe "generate_beam/3" do
    test "generates a valid Rust Beam orchestrator" do
      code = Component.generate_beam("DataIngestionBeam", "Orchestrates batch ingestion")

      assert String.contains?(code, "pub struct DataIngestionBeam;")
      assert String.contains?(code, "impl LuxBeam for DataIngestionBeam")
      assert String.contains?(code, "async fn run(&self, initial_state: Value)")
    end
  end
end

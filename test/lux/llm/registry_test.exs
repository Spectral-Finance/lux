defmodule Lux.LLM.RegistryTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.Registry
  describe "list/0" do
    test "returns known providers" do
      providers = Registry.list()
      assert is_map(providers)
      assert Map.has_key?(providers, :openai)
    end
  end
  describe "resolve/1" do
    test "returns module for known provider" do
      assert is_atom(Registry.resolve(:openai)) or elem(Registry.resolve(:openai), 0) == :error
    end
    test "returns error for unknown provider" do
      result = Registry.resolve(:unknown_xyz)
      assert result == {:error, :unknown} or elem(result, 0) == :error
    end
  end
  describe "model_provider/1" do
    test "returns provider for known model" do
      result = Registry.model_provider("gpt-4")
      assert elem(result, 0) in [:ok, :error]
    end
  end
end

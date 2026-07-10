defmodule Lux.Integrations.DuneTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Dune

  describe "api_key/0" do
    test "returns nil when no config or env is set" do
      # Temporarily clear config
      original = Application.get_env(:lux, Dune)
      Application.put_env(:lux, Dune, [])

      # Also ensure env var is not set for this test
      original_env = System.get_env("DUNE_API_KEY")
      System.delete_env("DUNE_API_KEY")

      assert Dune.api_key() == nil

      # Restore
      if original, do: Application.put_env(:lux, Dune, original)
      if original_env, do: System.put_env("DUNE_API_KEY", original_env)
    end

    test "returns key from application config" do
      original = Application.get_env(:lux, Dune)
      Application.put_env(:lux, Dune, api_key: "test-key-from-config")

      assert Dune.api_key() == "test-key-from-config"

      if original, do: Application.put_env(:lux, Dune, original), else: Application.delete_env(:lux, Dune)
    end
  end

  describe "authenticate/1" do
    test "injects x-dune-api-key header when not present" do
      Application.put_env(:lux, Dune, api_key: "my-test-key")

      lens = %{headers: [{"accept", "application/json"}]}
      result = Dune.authenticate(lens)

      assert {"x-dune-api-key", "my-test-key"} in result.headers

      Application.delete_env(:lux, Dune)
    end

    test "skips injection when x-dune-api-key already present" do
      lens = %{headers: [{"x-dune-api-key", "existing-key"}]}
      result = Dune.authenticate(lens)

      assert result == lens
    end

    test "raises ArgumentError when no API key is configured" do
      Application.put_env(:lux, Dune, [])
      System.delete_env("DUNE_API_KEY")

      lens = %{headers: []}

      assert_raise ArgumentError, ~r/Dune API key not configured/, fn ->
        Dune.authenticate(lens)
      end
    end
  end

  describe "base_url/0" do
    test "returns the Dune API v1 base URL" do
      assert Dune.base_url() == "https://api.dune.com/api/v1"
    end
  end
end

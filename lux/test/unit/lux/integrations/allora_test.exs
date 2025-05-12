defmodule Lux.Integrations.AlloraTest do
  @moduledoc """
  Test suite for the Allora integration module.
  These tests verify:
  - Header management
  - Authentication configuration
  - Chain ID resolution
  - Base URL configuration
  """

  use UnitCase, async: true
  alias Lux.Integrations.Allora

  describe "headers/0" do
    test "returns basic headers" do
      headers = Allora.headers()
      assert {"accept", "application/json"} in headers
      assert {"content-type", "application/json"} in headers
      refute Enum.any?(headers, fn {key, _} -> String.downcase(key) == "x-api-key" end)
    end
  end

  describe "auth/0" do
    test "returns custom auth configuration" do
      auth = Allora.auth()
      assert auth.type == :api_key
      assert is_function(auth.key, 0)
    end
  end

  describe "authenticate/1" do
    setup do
      lens = %{
        headers: [
          {"Accept", "application/json"},
          {"Content-Type", "application/json"}
        ]
      }
      {:ok, lens: lens}
    end

    test "adds x-api-key header when not present", %{lens: lens} do
      result = Allora.authenticate(lens)
      assert {"x-api-key", _} = Enum.find(result.headers, fn {key, _} ->
        String.downcase(key) == "x-api-key"
      end)
    end

    test "does not add x-api-key header when already present", %{lens: lens} do
      lens = %{lens | headers: [{"x-api-key", "existing-key"} | lens.headers]}
      result = Allora.authenticate(lens)

      # Should only have one x-api-key header
      api_key_headers = Enum.filter(result.headers, fn {key, _} ->
        String.downcase(key) == "x-api-key"
      end)
      assert length(api_key_headers) == 1

      # Should preserve the existing key
      assert {"x-api-key", "existing-key"} in result.headers
    end

    test "handles case-insensitive header check", %{lens: lens} do
      variations = [
        {"X-API-KEY", "key1"},
        {"x-api-key", "key2"},
        {"X-Api-Key", "key3"}
      ]

      Enum.each(variations, fn {header_key, value} ->
        lens_with_header = %{lens | headers: [{header_key, value} | lens.headers]}
        result = Allora.authenticate(lens_with_header)

        # Should preserve the existing header
        assert {header_key, value} in result.headers

        # Should not add another x-api-key header
        api_key_headers = Enum.filter(result.headers, fn {key, _} ->
          String.downcase(key) == "x-api-key"
        end)
        assert length(api_key_headers) == 1
      end)
    end
  end

  describe "chain_id/0" do
    setup do
      on_exit(fn ->
        Application.put_env(:lux, :allora, [])
      end)
    end

    test "returns correct chain ID for testnet" do
      Application.put_env(:lux, :allora, chain_slug: "testnet")
      assert Allora.chain_id() == "allora-testnet-1"
    end

    test "defaults to testnet for unknown chain slug" do
      Application.put_env(:lux, :allora, chain_slug: "unknown")
      assert Allora.chain_id() == "allora-testnet-1"
    end
  end

  describe "base_url/0" do
    setup do
      on_exit(fn ->
        Application.put_env(:lux, :allora, [])
      end)
    end

    test "returns default base URL when not configured" do
      Application.delete_env(:lux, :allora)
      assert Allora.base_url() == "https://api.upshot.xyz/v2"
    end
  end
end

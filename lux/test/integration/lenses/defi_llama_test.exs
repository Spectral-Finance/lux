defmodule Lux.Integration.DefiLlamaTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.DefiLlama.GetProtocols
  alias Lux.Lenses.DefiLlama.GetTvl
  alias Lux.Lenses.DefiLlama.GetVolumes
  alias Lux.Lenses.DefiLlama.GetYields

  test "can fetch protocols from DeFiLlama" do
    assert {:ok, [first_protocol | _]} = GetProtocols.focus()
    assert is_map(first_protocol)
    assert Map.has_key?(first_protocol, "name")
    assert Map.has_key?(first_protocol, "tvl")
  end

  test "can fetch historical TVL from DeFiLlama" do
    assert {:ok, [first_tvl | _]} = GetTvl.focus()
    assert is_map(first_tvl)
    assert Map.has_key?(first_tvl, "date")
    assert Map.has_key?(first_tvl, "tvl")
  end

  test "can fetch volume analytics from DeFiLlama" do
    assert {:ok, %{"protocols" => protocols}} = GetVolumes.focus(%{dataType: "dailyVolume"})
    assert is_list(protocols)
    if length(protocols) > 0 do
      first = hd(protocols)
      assert Map.has_key?(first, "name")
    end
  end

  test "can fetch yields from DeFiLlama" do
    assert {:ok, [first_pool | _]} = GetYields.focus()
    assert is_map(first_pool)
    assert Map.has_key?(first_pool, "project")
    assert Map.has_key?(first_pool, "tvlUsd")
    assert Map.has_key?(first_pool, "apy")
  end
end

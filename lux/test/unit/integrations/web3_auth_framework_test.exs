defmodule Lux.Integrations.Web3.AuthFrameworkTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.AuthFramework

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.AuthFramework.process(%{})
    assert {:ok, %{verified: true, issue: 77}} = Web3.AuthFramework.process(%{active: true})
    assert {:ok, 95.0} = Web3.AuthFramework.compute_efficiency_score(100, 100, 500)
  end
end

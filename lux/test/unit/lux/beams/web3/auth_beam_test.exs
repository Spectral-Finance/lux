defmodule Lux.Beams.Web3.AuthBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Web3.AuthBeam

  @test_address "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"
  @test_sig "0x" <> String.duplicate("ab", 65)

  describe "run/1" do
    test "executes full authentication and authorization pipeline" do
      input = %{
        address: @test_address,
        message: "Sign in to Lux Agentic Network",
        signature: @test_sig,
        required_permission: "read_data",
        roles: ["user"]
      }

      assert {:ok, result, execution_log} = AuthBeam.run(input)
      assert result.address == @test_address
      assert is_boolean(result.authenticated)
      assert result.authorized == true
      assert is_binary(result.token)
      assert is_binary(result.session_id)
      assert execution_log.status == :completed
      assert length(execution_log.steps) >= 3
    end
  end
end

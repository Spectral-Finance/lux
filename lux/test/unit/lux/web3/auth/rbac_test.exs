defmodule Lux.Web3.Auth.RBACTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Auth.RBAC

  describe "authorized?/4" do
    test "authorizes role permissions" do
      policy = %{
        admin: [%{action: :*, resource: :*}],
        analyst: [%{action: :read, resource: :signals}]
      }

      assert RBAC.authorized?(%{roles: [:analyst]}, :read, :signals, policy)
      refute RBAC.authorized?(%{roles: [:analyst]}, :write, :signals, policy)
      assert RBAC.authorized?(%{roles: [:admin]}, :delete, :sessions, policy)
    end
  end
end

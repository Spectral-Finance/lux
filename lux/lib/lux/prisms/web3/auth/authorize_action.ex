defmodule Lux.Prisms.Web3.Auth.AuthorizeActionPrism do
  @moduledoc """
  Evaluates role-based permissions to authorize or deny a requested action.
  """

  use Lux.Prism,
    name: "Authorize Web3 Action",
    description: "Evaluates role-based access control (RBAC) permissions for an address or role list",
    input_schema: %{
      type: :object,
      properties: %{
        roles: %{type: :array, items: %{type: :string}, description: "Roles held by subject"},
        address: %{type: :string, description: "Wallet address of subject"},
        required_permission: %{type: :string, description: "Action or permission required (e.g. execute_trades)"},
        assignments: %{type: :object, description: "Optional map of address-to-roles assignments"}
      },
      required: ["required_permission"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        authorized: %{type: :boolean},
        required_permission: %{type: :string},
        effective_roles: %{type: :array, items: %{type: :string}}
      },
      required: ["authorized", "required_permission"]
    }

  alias Lux.Web3.Auth.RBAC

  def handler(input, _ctx) do
    raw_perm = Map.get(input, :required_permission) || Map.get(input, "required_permission")
    perm = if is_binary(raw_perm), do: String.to_atom(raw_perm), else: raw_perm
    raw_roles = Map.get(input, :roles) || Map.get(input, "roles")
    address = Map.get(input, :address) || Map.get(input, "address")
    assignments = Map.get(input, :assignments) || Map.get(input, "assignments")

    subject =
      cond do
        is_list(raw_roles) and raw_roles != [] ->
          Enum.map(raw_roles, fn r -> if is_binary(r), do: String.to_atom(r), else: r end)

        is_binary(address) ->
          address

        true ->
          [:guest]
      end

    authorized = RBAC.has_permission?(subject, perm, assignments)

    effective_roles =
      case subject do
        roles when is_list(roles) -> Enum.map(roles, &to_string/1)
        addr when is_binary(addr) and is_map(assignments) ->
          clean = String.downcase(addr)
          Enum.map(Map.get(assignments, clean, [:guest]), &to_string/1)
        _ -> ["user"]
      end

    {:ok,
     %{
       authorized: authorized,
       required_permission: to_string(perm),
       effective_roles: effective_roles
     }}
  end
end

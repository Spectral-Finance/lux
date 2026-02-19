defmodule Lux.Lenses.Web3.Auth.AuditLogLens do
  @moduledoc """
  A lens for querying the Web3 authentication audit log.

  Provides filtered access to security events including authentication attempts,
  session management actions, role changes, and permission checks.

  ## Examples

      iex> AuditLogLens.focus(%{
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
      ...>   action: "auth_success",
      ...>   limit: 10
      ...> })
      {:ok, %{events: [...], count: 5}}
  """

  use Lux.Lens,
    name: "Web3 Auth Audit Log",
    description: "Queries the Web3 authentication audit log",
    url: "local://web3/auth/audit",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Filter by wallet address"
        },
        action: %{
          type: :string,
          description: "Filter by action type (e.g., auth_success, auth_failure)"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of events to return (default: 100)"
        }
      }
    }

  alias Lux.Web3.Auth.AuditLog

  @doc """
  Override after_focus to process audit log query results.
  In practice, this lens uses a custom focus that doesn't call HTTP.
  Use `query/1` to query the audit log directly.
  """
  def after_focus(body), do: {:ok, body}

  @doc """
  Queries the audit log with the given parameters.

  This bypasses the HTTP-based lens focus to query the local ETS store directly.

  ## Parameters

    * `params` - Map with optional filter keys:
      * `:address` - Filter by wallet address
      * `:action` - Filter by action type string
      * `:limit` - Maximum results (default 100)

  ## Returns

    * `{:ok, %{events: [...], count: integer()}}`
  """
  @spec query(map()) :: {:ok, map()}
  def query(params \\ %{}) do
    filters =
      []
      |> maybe_add_filter(:address, params[:address] || params["address"])
      |> maybe_add_filter(:action, parse_action(params[:action] || params["action"]))
      |> maybe_add_filter(:limit, params[:limit] || params["limit"] || 100)

    events = AuditLog.query(filters)

    {:ok,
     %{
       events:
         Enum.map(events, fn e ->
           %{
             id: e.id,
             action: e.action,
             address: e.address,
             timestamp: DateTime.to_iso8601(e.timestamp),
             metadata: e.metadata
           }
         end),
       count: length(events)
     }}
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Keyword.put(filters, key, value)

  defp parse_action(nil), do: nil
  defp parse_action(action) when is_atom(action), do: action

  defp parse_action(action) when is_binary(action) do
    String.to_existing_atom(action)
  rescue
    ArgumentError -> nil
  end
end

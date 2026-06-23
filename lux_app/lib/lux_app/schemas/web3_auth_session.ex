defmodule LuxApp.Schemas.Web3AuthSession do
  @moduledoc """
  Schema for Web3 authentication sessions using EIP-4361 (Sign-In with Ethereum).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "web3_auth_sessions" do
    field :wallet_address, :string
    field :chain_id, :integer
    field :nonce, :string
    field :domain, :string
    field :statement, :string
    field :signature, :string
    field :issued_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :metadata, :map, default: %{}
    field :roles, {:array, :string}, default: []
    field :permissions, {:array, :map}, default: []

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          wallet_address: String.t(),
          chain_id: integer(),
          nonce: String.t(),
          domain: String.t(),
          statement: String.t() | nil,
          signature: String.t(),
          issued_at: NaiveDateTime.t(),
          expires_at: NaiveDateTime.t(),
          revoked_at: NaiveDateTime.t() | nil,
          metadata: map(),
          roles: [String.t()],
          permissions: [map()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :wallet_address,
      :chain_id,
      :nonce,
      :domain,
      :statement,
      :signature,
      :issued_at,
      :expires_at,
      :revoked_at,
      :metadata,
      :roles,
      :permissions
    ])
    |> validate_required([:wallet_address, :chain_id, :nonce, :domain, :signature, :issued_at, :expires_at])
    |> validate_format(:wallet_address, ~r/^0x[a-fA-F0-9]{40}$/,
      message: "must be a valid Ethereum address"
    )
    |> validate_inclusion(:chain_id, [1, 5, 10, 137, 42161, 8453, 11155111])
  end
end

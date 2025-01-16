defmodule Lux.Engine.Subscription do
  @moduledoc """
  Defines a subscription pattern for matching signals.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          pattern: map(),
          specter_id: String.t()
        }

  defstruct [:id, :pattern, :specter_id]

  @doc """
  Creates a new subscription for a specter with the given pattern.
  """
  def new(pattern, specter_id) when is_map(pattern) and is_binary(specter_id) do
    %__MODULE__{
      id: Lux.UUID.generate(),
      pattern: pattern,
      specter_id: specter_id
    }
  end

  @doc """
  Converts a subscription to ETS record format.
  Returns {key, value} tuple for ETS insertion.
  """
  def to_ets_record(%__MODULE__{} = subscription) do
    key = {subscription.pattern, subscription.id}
    # Empty list for future match_spec
    value = {[], subscription.specter_id}
    {key, value}
  end
end

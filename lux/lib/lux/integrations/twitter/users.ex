defmodule Lux.Integrations.Twitter.Users do
  @moduledoc """
  User profile lookup and management operations via Twitter API v2 (`/2/users`).
  """

  alias Lux.Integrations.Twitter.Client

  @default_user_fields [
    "id",
    "name",
    "username",
    "created_at",
    "description",
    "location",
    "profile_image_url",
    "protected",
    "public_metrics",
    "url",
    "verified"
  ]

  @doc """
  Retrieves information about the authenticated user (`/2/users/me`).
  """
  @spec get_me(map()) :: {:ok, map()} | {:error, term()}
  def get_me(opts \\ %{}) do
    fields = Map.get(opts, :fields, @default_user_fields)
    params = %{"user.fields" => Enum.join(fields, ",")}

    req_opts = Map.put(opts, :params, params)
    Client.request(:get, "/users/me", req_opts)
  end

  @doc """
  Retrieves user details by their Twitter handle / username.
  """
  @spec get_user_by_username(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_user_by_username(username, opts \\ %{}) do
    username = String.trim_leading(username, "@")
    fields = Map.get(opts, :fields, @default_user_fields)
    params = %{"user.fields" => Enum.join(fields, ",")}

    req_opts = Map.put(opts, :params, params)
    Client.request(:get, "/users/by/username/#{username}", req_opts)
  end

  @doc """
  Retrieves user details by numerical user ID.
  """
  @spec get_user_by_id(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_user_by_id(user_id, opts \\ %{}) do
    fields = Map.get(opts, :fields, @default_user_fields)
    params = %{"user.fields" => Enum.join(fields, ",")}

    req_opts = Map.put(opts, :params, params)
    Client.request(:get, "/users/#{user_id}", req_opts)
  end
end

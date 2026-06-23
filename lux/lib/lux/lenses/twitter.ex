defmodule Lux.Lens.Twitter do
  @moduledoc """
  Base module namespace and structs for Twitter Lenses.
  """
  
  defstruct [:client_id, :client_secret]
end

defmodule Lux.Lens.Twitter.Profile do
  @moduledoc """
  Struct representing a Twitter Profile.
  """
  defstruct [:id, :name, :username, :description, :profile_image_url]
end

defmodule Lux.Lens.Twitter.Tweet do
  @moduledoc """
  Struct representing a Twitter Tweet.
  """
  defstruct [:id, :text, :author_id, :created_at, :public_metrics]
end

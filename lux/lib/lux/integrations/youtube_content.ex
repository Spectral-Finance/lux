defmodule Lux.Integrations.YouTubeContent do
  @moduledoc """
  YouTube Content Creation Pipeline ($2,500).

  Helpers for scripting, thumbnail generation metadata,
  SEO optimisation, upload management, and A/B testing.
  """

  alias Lux.Integrations.YouTube

  @upload_url "https://www.googleapis.com/upload/youtube/v3/videos"
  @max_title_len   100
  @max_desc_len   5_000
  @max_tags         500
  @max_tag_chars     30

  def upload_url, do: @upload_url

  @doc "Validates video metadata before upload."
  @spec validate_metadata(map()) :: :ok | {:error, list(String.t())}
  def validate_metadata(%{title: title, description: description, tags: tags} = _meta) do
    errors = []
    errors = if byte_size(title) > @max_title_len, do: ["title exceeds #{@max_title_len} chars" | errors], else: errors
    errors = if byte_size(description) > @max_desc_len, do: ["description exceeds #{@max_desc_len} chars" | errors], else: errors
    errors = if length(tags) > @max_tags, do: ["too many tags (max #{@max_tags})" | errors], else: errors
    over = Enum.filter(tags, &(byte_size(&1) > @max_tag_chars))
    errors = if over != [], do: ["tags too long: #{inspect(over)}" | errors], else: errors
    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end
  def validate_metadata(_), do: {:error, ["missing required fields: title, description, tags"]}

  @doc "Generates SEO-optimised title variants for A/B testing."
  @spec title_variants(String.t(), list(String.t())) :: list(String.t())
  def title_variants(base_title, hooks \\ []) do
    prefixes = ["How to", "Why", "The Truth About", "Top 5"]
    all_hooks = if hooks == [], do: prefixes, else: hooks
    Enum.map(all_hooks, fn hook -> "#{hook}: #{base_title}" end)
  end

  @doc "Builds upload request body for YouTube Data API v3."
  @spec build_upload_body(map()) :: map()
  def build_upload_body(%{title: title, description: desc, tags: tags,
                           category_id: cat, privacy: privacy}) do
    %{
      snippet: %{
        title: title,
        description: desc,
        tags: tags,
        categoryId: to_string(cat),
        defaultLanguage: "en",
        defaultAudioLanguage: "en"
      },
      status: %{
        privacyStatus: to_string(privacy),
        selfDeclaredMadeForKids: false
      }
    }
  end

  @doc "YouTube video categories most relevant for tech/AI content."
  def tech_categories, do: %{science_tech: 28, education: 27, howto: 26, entertainment: 24}
end

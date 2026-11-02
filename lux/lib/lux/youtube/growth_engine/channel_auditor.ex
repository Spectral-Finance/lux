defmodule Lux.YouTube.GrowthEngine.ChannelAuditor do
  @moduledoc """
  Conducts comprehensive automated channel audits assessing metadata hygiene,
  upload cadence consistency, audience conversion funnels, and algorithmic health.
  """

  @type audit_report :: %{
          channel_name: String.t(),
          overall_score: float(),
          health_grade: :a_plus | :a | :b | :c | :f,
          category_scores: %{
            metadata_health: float(),
            cadence_consistency: float(),
            ctr_performance: float(),
            funnel_conversion: float()
          },
          critical_issues: list(String.t()),
          quick_wins: list(String.t())
        }

  @doc """
  Audits channel parameters and compiles diagnostic health ratings.
  """
  @spec audit_channel(map()) :: audit_report()
  def audit_channel(channel_data) when is_map(channel_data) do
    name = get_val(channel_data, :channel_name, "Channel")
    avg_ctr = get_val(channel_data, :average_ctr, 4.2)
    uploads_per_month = get_val(channel_data, :uploads_per_month, 4)
    has_custom_thumbnails = get_val(channel_data, :custom_thumbnails_ratio, 1.0)
    has_chapters = get_val(channel_data, :chapters_present_ratio, 0.8)
    sub_conversion_rate = get_val(channel_data, :sub_conversion_rate, 15.0) # per 10k views

    # Score category 1: Metadata Health (0 - 100)
    metadata_score = Float.round((has_custom_thumbnails * 50.0) + (has_chapters * 50.0), 1)

    # Score category 2: Cadence (0 - 100)
    cadence_score =
      cond do
        uploads_per_month >= 8 -> 100.0
        uploads_per_month >= 4 -> 85.0
        uploads_per_month >= 2 -> 65.0
        true -> 40.0
      end

    # Score category 3: CTR Performance (0 - 100)
    ctr_score = Float.round(min((avg_ctr / 6.0) * 100.0, 100.0), 1)

    # Score category 4: Funnel conversion (0 - 100)
    funnel_score = Float.round(min((sub_conversion_rate / 25.0) * 100.0, 100.0), 1)

    overall =
      Float.round(
        metadata_score * 0.25 +
          cadence_score * 0.25 +
          ctr_score * 0.30 +
          funnel_score * 0.20,
        1
      )

    grade =
      cond do
        overall >= 92.0 -> :a_plus
        overall >= 80.0 -> :a
        overall >= 68.0 -> :b
        overall >= 50.0 -> :c
        true -> :f
      end

    {issues, wins} = compile_recommendations(avg_ctr, uploads_per_month, has_chapters, sub_conversion_rate)

    %{
      channel_name: name,
      overall_score: overall,
      health_grade: grade,
      category_scores: %{
        metadata_health: metadata_score,
        cadence_consistency: cadence_score,
        ctr_performance: ctr_score,
        funnel_conversion: funnel_score
      },
      critical_issues: issues,
      quick_wins: wins
    }
  end

  defp compile_recommendations(ctr, uploads, chapters, sub_conv) do
    issues = []
    wins = []

    {issues, wins} =
      if ctr < 4.5 do
        {["Average Click-Through Rate (#{ctr}%) is below the healthy 5.0% threshold." | issues],
         ["Redesign thumbnail faces with high-contrast outlines and limit text badges to 3 words." | wins]}
      else
        {issues, wins}
      end

    {issues, wins} =
      if uploads < 4 do
        {["Upload cadence is irregular (#{uploads} videos/mo); YouTube algorithm rewards weekly consistency." | issues],
         ["Commit to a predictable publishing schedule (e.g., every Thursday at 2 PM EST)." | wins]}
      else
        {issues, wins}
      end

    {issues, wins} =
      if chapters < 0.7 do
        {["Over 30% of videos lack formatted timestamp chapters." | issues],
         ["Add timestamp chapters to all videos >5 minutes to rank in Google video search results." | wins]}
      else
        {issues, wins}
      end

    {issues, wins} =
      if sub_conv < 12.0 do
        {["Viewer-to-subscriber conversion rate is under-indexing (<12 subs per 10k views)." | issues],
         ["Add an explicit visual call-to-action lower third at the 60% completion point." | wins]}
      else
        {issues, wins}
      end

    {Enum.reverse(issues), Enum.reverse(wins)}
  end

  defp get_val(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end

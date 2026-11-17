defmodule Lux.Beams.DiscordModerationFlow do
  @moduledoc """
  An example Beam demonstrating how to chain Discord Prisms for an automated workflow.
  """
  use Lux.Beam

  def workflow(input) do
    # 1. Filter content
    # 2. If toxic, send warning
    # 3. If repeat offender, timeout
    step :analyze_content, Lux.Prisms.ContentAnalysis
    step :apply_moderation, Lux.Prisms.Discord.Moderation, 
      when: fn result -> result.is_toxic == true end
    step :notify_admin, Lux.Prisms.Discord.MessageManagement
  end
end

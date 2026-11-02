defmodule Lux.YouTube.ContentCreation.EditingAdvisor do
  @moduledoc """
  Generates automated editing timelines, B-roll cues, sound effect (SFX) triggers,
  and dynamic camera pacing suggestions for video editors.
  """

  @type cut_type :: :punch_in | :wide_angle | :screen_zoom | :b_roll_overlay | :graphic_lower_third

  @type edit_cue :: %{
          timestamp: String.t(),
          visual_action: String.t(),
          camera_framing: cut_type(),
          sound_effect: String.t(),
          duration_seconds: float(),
          editor_tip: String.t()
        }

  @type editing_timeline :: %{
          total_cues: non_neg_integer(),
          recommended_cut_frequency_seconds: float(),
          cues: list(edit_cue()),
          audio_mastering_specs: map()
        }

  @doc """
  Constructs an edit timeline with camera, SFX, and B-roll markers based on script chapters.
  """
  @spec generate_editing_cues(list(map()) | map()) :: editing_timeline()
  def generate_editing_cues(script_or_sections) do
    sections =
      case script_or_sections do
        %{sections: s} -> s
        s when is_list(s) -> s
        _ -> []
      end

    cues =
      sections
      |> Enum.with_index()
      |> Enum.flat_map(fn {section, index} ->
        ts = Map.get(section, :timestamp_estimate, "00:00")
        name = Map.get(section, :name, "Chapter #{index}")
        build_section_cues(ts, name, index)
      end)

    %{
      total_cues: length(cues),
      recommended_cut_frequency_seconds: 4.5,
      cues: cues,
      audio_mastering_specs: %{
        target_loudness_lufs: -14.0,
        true_peak_db: -1.0,
        voiceover_eq: "High-pass filter at 80Hz, presence boost at 3.5kHz",
        background_music_ducking_db: -18.0
      }
    }
  end

  defp build_section_cues(timestamp, "Hook" <> _, _idx) do
    [
      %{
        timestamp: timestamp,
        visual_action: "Fast montage of system architecture, high-speed code typing, and key metric spike",
        camera_framing: :b_roll_overlay,
        sound_effect: "Subtle sub-bass drop followed by fast riser",
        duration_seconds: 4.0,
        editor_tip: "Do not linger on any single shot longer than 1.5 seconds in the first 10 seconds."
      },
      %{
        timestamp: "00:04",
        visual_action: "Punch in to close-up face camera as thesis is stated",
        camera_framing: :punch_in,
        sound_effect: "Quick whoosh transition",
        duration_seconds: 5.0,
        editor_tip: "10% crop punch-in creates visual rhythm without re-framing camera."
      }
    ]
  end

  defp build_section_cues(timestamp, "Call to Action" <> _, _idx) do
    [
      %{
        timestamp: timestamp,
        visual_action: "Lower-third animated badge showing GitHub star button and Subscribe bell",
        camera_framing: :graphic_lower_third,
        sound_effect: "Crisp mouse click + gentle chime",
        duration_seconds: 6.0,
        editor_tip: "Keep animation non-intrusive on the bottom-left third."
      }
    ]
  end

  defp build_section_cues(timestamp, name, index) do
    framing = if rem(index, 2) == 0, do: :screen_zoom, else: :punch_in
    sfx = if rem(index, 2) == 0, do: "Pop sound on bullet point highlight", else: "Soft paper slide / whoosh"

    [
      %{
        timestamp: timestamp,
        visual_action: "Transition into #{name} with animated chapter header card",
        camera_framing: framing,
        sound_effect: sfx,
        duration_seconds: 5.0,
        editor_tip: "Zoom in on relevant code line or terminal output to guide viewer eye."
      }
    ]
  end
end

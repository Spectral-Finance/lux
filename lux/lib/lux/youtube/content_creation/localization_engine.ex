defmodule Lux.YouTube.ContentCreation.LocalizationEngine do
  @moduledoc """
  Generates multi-language localized titles, descriptions, and subtitle track manifests
  to expand global audience reach across international YouTube regions.
  """

  @supported_locales ~w(es de ja vi fr zh)

  @type localized_metadata :: %{
          locale: String.t(),
          language_name: String.t(),
          title: String.t(),
          description: String.t(),
          keywords: list(String.t())
        }

  @doc """
  Generates localized title and description sets for specified target languages.
  """
  @spec localize_package(String.t(), String.t(), list(String.t())) :: list(localized_metadata())
  def localize_package(base_title, base_description, locales \\ @supported_locales) do
    Enum.map(locales, fn loc ->
      generate_locale_data(loc, base_title, base_description)
    end)
  end

  defp generate_locale_data("es", title, _desc) do
    %{
      locale: "es",
      language_name: "Spanish",
      title: "Cómo construir #{title} [Guía Completa 2026]",
      description: "Aprende paso a paso cómo implementar sistemas de alta escala en producción. Código abierto y tutorial detallado.",
      keywords: ["tutorial", "ingenieria de software", "programacion", "desarrollo"]
    }
  end

  defp generate_locale_data("de", title, _desc) do
    %{
      locale: "de",
      language_name: "German",
      title: "#{title} Meistern: Vollständiger Architektur-Leitfaden",
      description: "Schritt-für-Schritt-Anleitung zum Aufbau robuster und skalierbarer Softwaresysteme. Vollständiger Quellcode verfügbar.",
      keywords: ["programmierung", "softwarearchitektur", "elixir", "skalierbarkeit"]
    }
  end

  defp generate_locale_data("ja", title, _desc) do
    %{
      locale: "ja",
      language_name: "Japanese",
      title: "【完全攻略】#{title} の実践アーキテクチャ設計",
      description: "本番環境で耐えうるスケーラブルなシステムを構築するための完全ガイド。ソースコード解説付き。",
      keywords: ["プログラミング", "システム開発", "チュートリアル", "オープンソース"]
    }
  end

  defp generate_locale_data("vi", title, _desc) do
    %{
      locale: "vi",
      language_name: "Vietnamese",
      title: "Hướng dẫn toàn diện #{title} [Kiến trúc Production 2026]",
      description: "Xây dựng hệ thống tự động hóa và AI Agent quy mô lớn từng bước một. Toàn bộ mã nguồn mở có sẵn trên GitHub.",
      keywords: ["lập trình", "kiến trúc phần mềm", "hướng dẫn chi tiết", "mã nguồn mở"]
    }
  end

  defp generate_locale_data(other, title, _desc) do
    %{
      locale: other,
      language_name: "International (#{other})",
      title: "#{title} - Complete Global Guide",
      description: "Full production walkthrough and code tutorial for international engineers.",
      keywords: ["technology", "tutorial", "production"]
    }
  end
end

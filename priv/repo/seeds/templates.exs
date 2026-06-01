# Seeds gallery templates and layout slots. Loaded from priv/repo/seeds.exs.

alias SuchGalleryElixir.Repo
alias SuchGalleryElixir.Galleries.{GalleryTemplate, LayoutSlot}

import Ecto.Query

defmodule SuchGalleryElixir.Seeds.Templates do
  @moduledoc false

  @templates [
    %{
      slug: "minimal_4",
      name: "Minimal (4 frames)",
      slot_count: 4,
      layout: :rectangular,
      width: 8.0,
      depth: 6.0
    },
    %{
      slug: "show_32",
      name: "Show (32 frames)",
      slot_count: 32,
      layout: :rectangular,
      width: 16.0,
      depth: 12.0
    }
  ]

  def run do
    for attrs <- @templates do
      seed_template(attrs)
    end

    :ok
  end

  defp seed_template(attrs) do
    case Repo.get_by(GalleryTemplate, slug: attrs.slug) do
      nil ->
        {:ok, template} =
          %GalleryTemplate{}
          |> GalleryTemplate.changeset(attrs)
          |> Repo.insert()

        insert_slots(template, attrs.slot_count)

      existing ->
        cond do
          slot_count(existing) == attrs.slot_count ->
            :ok

          slot_count(existing) == 0 ->
            insert_slots(existing, attrs.slot_count)

          true ->
            raise "template #{attrs.slug} exists with different slot count"
        end
    end
  end

  defp slot_count(template) do
    LayoutSlot
    |> where([s], s.template_id == ^template.id)
    |> Repo.aggregate(:count)
  end

  defp insert_slots(template, count) do
    slots =
      for index <- 0..(count - 1) do
        u = (index + 1) / (count + 1)

        %{
          template_id: template.id,
          slot_index: index,
          wall: :back,
          u: u,
          v: 0.5,
          rotation_y: 0.0,
          scale: 1.0,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      end

    Repo.insert_all(LayoutSlot, slots)
  end
end

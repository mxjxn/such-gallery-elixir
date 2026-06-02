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
    },
    %{
      slug: "square_32",
      name: "Square room (8 per wall)",
      slot_count: 32,
      layout: :rectangular,
      width: 12.0,
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
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    slots =
      case template.slug do
        "square_32" -> square_wall_slots(template.id, now)
        _ -> back_wall_slots(template.id, count, now)
      end

    Repo.insert_all(LayoutSlot, slots)
  end

  defp back_wall_slots(template_id, count, now) do
    for index <- 0..(count - 1) do
      u = (index + 1) / (count + 1)

      %{
        template_id: template_id,
        slot_index: index,
        wall: :back,
        u: u,
        v: 0.5,
        rotation_y: 0.0,
        scale: 1.0,
        inserted_at: now,
        updated_at: now
      }
    end
  end

  # Square room: 8 frames on each of 4 walls (32 total).
  defp square_wall_slots(template_id, now) do
    walls = [:back, :right, :front, :left]

    for {wall, wall_index} <- Enum.with_index(walls),
        index <- 0..7 do
      %{
        template_id: template_id,
        slot_index: wall_index * 8 + index,
        wall: wall,
        u: (index + 1) / 9.0,
        v: 0.5,
        rotation_y: 0.0,
        scale: 1.0,
        inserted_at: now,
        updated_at: now
      }
    end
  end
end

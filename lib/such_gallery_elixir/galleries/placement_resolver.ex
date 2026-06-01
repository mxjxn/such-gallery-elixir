defmodule SuchGalleryElixir.Galleries.PlacementResolver do
  @moduledoc """
  Computes world-space transforms for placements from template slots or extras.

  Keeps Three.js and channels dumb: they receive resolved x/y/z and rotation_y.
  """

  alias SuchGalleryElixir.Galleries.{ArtworkPlacement, Gallery, LayoutSlot}

  @wall_height 3.0

  @doc """
  Resolves a list of placements for a preloaded gallery into maps ready for the client.
  """
  def resolve_all(placements, %Gallery{} = gallery) when is_list(placements) do
    Enum.map(placements, &resolve(&1, gallery))
  end

  @doc "Resolves a single preloaded placement."
  def resolve(%ArtworkPlacement{kind: :slot} = placement, %Gallery{} = gallery) do
    slot = placement.layout_slot

    {x, y, z, rotation_y, scale} =
      slot_to_world(slot, Gallery.width(gallery), Gallery.depth(gallery))

    base_map(placement)
    |> Map.merge(%{
      x: x,
      y: y,
      z: z,
      rotation_y: rotation_y,
      scale: scale,
      wall: slot.wall
    })
  end

  def resolve(%ArtworkPlacement{kind: :extra} = placement, %Gallery{} = gallery) do
    pseudo_slot = %LayoutSlot{
      wall: placement.override_wall,
      u: placement.override_u,
      v: placement.override_v,
      rotation_y: placement.override_rotation_y || 0.0,
      scale: placement.override_scale || 1.0
    }

    {x, y, z, rotation_y, scale} =
      slot_to_world(pseudo_slot, Gallery.width(gallery), Gallery.depth(gallery))

    base_map(placement)
    |> Map.merge(%{
      x: x,
      y: y,
      z: z,
      rotation_y: rotation_y,
      scale: scale,
      wall: placement.override_wall
    })
  end

  defp base_map(%ArtworkPlacement{} = placement) do
    artwork = placement.artwork

    %{
      id: placement.id,
      kind: placement.kind,
      display_order: placement.display_order,
      layout_slot_id: placement.layout_slot_id,
      artwork_id: placement.artwork_id,
      artwork_url: artwork.artwork_url,
      title: artwork.title,
      artist: artwork.artist
    }
  end

  defp slot_to_world(%LayoutSlot{} = slot, width, depth) do
    u = slot.u
    v = slot.v
    scale = slot.scale
    extra_rotation = slot.rotation_y

    case slot.wall do
      :back ->
        { (u - 0.5) * width,
          v * @wall_height,
          -depth / 2 + 0.01,
          extra_rotation,
          scale }

      :left ->
        { -width / 2 + 0.01,
          v * @wall_height,
          (u - 0.5) * depth,
          extra_rotation + :math.pi() / 2,
          scale }

      :right ->
        { width / 2 - 0.01,
          v * @wall_height,
          (u - 0.5) * depth,
          extra_rotation - :math.pi() / 2,
          scale }
    end
  end
end

defmodule SuchGalleryElixirWeb.GalleryLive.Form do
  use SuchGalleryElixirWeb, :live_view

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.Galleries.Gallery

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :templates, Galleries.list_templates())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    socket =
      case live_action do
        :new ->
          template_slug = params["template"] || "square_32"
          gallery = %Gallery{}
          changeset = Gallery.changeset(gallery, %{})
          assign(socket, gallery: nil, changeset: changeset, template_slug: template_slug, show_delete_confirm: false)

        :edit ->
          gallery = Galleries.get_gallery_by_slug(params["slug"])

          if gallery do
            changeset = Gallery.changeset(gallery, %{})
            assign(socket, gallery: gallery, changeset: changeset, show_delete_confirm: false)
          else
            socket
            |> put_flash(:error, "Gallery not found")
            |> push_navigate(to: ~p"/")
          end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"gallery" => gallery_params}, socket) do
    gallery = socket.assigns.gallery || %Gallery{}

    changeset =
      gallery
      |> Gallery.changeset(gallery_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"gallery" => gallery_params}, socket) do
    case socket.assigns.live_action do
      :new ->
        template_slug = gallery_params["template_slug"] || socket.assigns.template_slug

        attrs =
          gallery_params
          |> Map.delete("template_slug")

        case Galleries.create_gallery(attrs, template_slug) do
          {:ok, gallery} ->
            {:noreply,
             socket
             |> put_flash(:info, "Gallery created successfully.")
             |> push_navigate(to: ~p"/gallery/#{gallery.slug}")}

          {:error, :template_not_found} ->
            changeset =
              %Gallery{}
              |> Gallery.changeset(attrs)
              |> Map.put(:action, :validate)
              |> add_error(:template_id, "template not found")

            {:noreply, assign(socket, :changeset, changeset)}

          {:error, changeset} ->
            changeset = Map.put(changeset, :action, :validate)
            {:noreply, assign(socket, :changeset, changeset)}
        end

      :edit ->
        gallery = socket.assigns.gallery

        case Galleries.update_gallery(gallery, gallery_params) do
          {:ok, gallery} ->
            {:noreply,
             socket
             |> put_flash(:info, "Gallery updated successfully.")
             |> push_navigate(to: ~p"/gallery/#{gallery.slug}")}

          {:error, changeset} ->
            changeset = Map.put(changeset, :action, :validate)
            {:noreply, assign(socket, :changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("show_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    gallery = socket.assigns.gallery

    case Galleries.delete_gallery(gallery) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gallery deleted.")
         |> push_navigate(to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not delete gallery.")
         |> assign(:show_delete_confirm, false)}
    end
  end

  defp add_error(changeset, key, message) do
    Ecto.Changeset.add_error(changeset, key, message)
  end
end

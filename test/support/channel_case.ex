defmodule SuchGalleryElixirWeb.ChannelCase do
  @moduledoc """
  Test case for channel tests with SQL sandbox and Phoenix.ChannelTest.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import SuchGalleryElixirWeb.ChannelCase

      @endpoint SuchGalleryElixirWeb.Endpoint
    end
  end

  setup tags do
    SuchGalleryElixir.DataCase.setup_sandbox(tags)
    Ecto.Adapters.SQL.Sandbox.mode(SuchGalleryElixir.Repo, {:shared, self()})
    :ok
  end
end

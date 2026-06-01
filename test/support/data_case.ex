defmodule SuchGalleryElixir.DataCase do
  @moduledoc """
  Test case for database-backed tests.

  Enables the SQL sandbox so each test runs in an isolated transaction.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias SuchGalleryElixir.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import SuchGalleryElixir.DataCase
    end
  end

  setup tags do
    SuchGalleryElixir.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox for a test (or the whole module when `async: true`).
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(SuchGalleryElixir.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

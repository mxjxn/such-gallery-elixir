defmodule SuchGalleryElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SuchGalleryElixirWeb.Telemetry,
      SuchGalleryElixir.Repo,
      {DNSCluster, query: Application.get_env(:such_gallery_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SuchGalleryElixir.PubSub},
      SuchGalleryElixirWeb.Presence,
      # Start a worker by calling: SuchGalleryElixir.Worker.start_link(arg)
      # {SuchGalleryElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      SuchGalleryElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SuchGalleryElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SuchGalleryElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

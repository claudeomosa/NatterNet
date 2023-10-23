defmodule Chat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "6666")

    children = [
      {Task.Supervisor, name: Chat.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Chat.ProxyServer.accept(port) end},
        restart: :permanent,
        id: Chat.ProxyServer
      ),
      Chat.ClientsStateAgent
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

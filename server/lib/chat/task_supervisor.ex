defmodule Chat.TaskSupervisor do
  @moduledoc """
    Chat Task Supervisor

    Manages child processes in the chat application, ensuring robust operation.

    ## Usage

    Start the supervisor with `Chat.TaskSupervisor.start_link(opts)`.

    ## Child Processes

    Supervises `Chat.ProxyServer` for client connections and interactions.

    Example:

    ```elixir
    {:ok, _} = Chat.TaskSupervisor.start_link([])
    ```
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      Chat.ProxyServer,
      [],
      restart: :temporary
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

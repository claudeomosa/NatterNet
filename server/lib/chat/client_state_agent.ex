defmodule Chat.ClientsStateAgent do
  @moduledoc """
    Chat Clients State Agent

    This module defines an Agent that manages client state in the chat application. It stores client PIDs and their associated sockets for communication.

    ## Usage

    To use this agent, start it with `Chat.ClientsStateAgent.start_link(opts)`. You can then add and remove clients and retrieve their information using provided functions.

    ## Functions

    - `add_client/2`: Add a client with its PID and socket.
    - `remove_client/1`: Remove a client using its PID.
    - `get_clients/0`: Get all client PIDs.
    - `get_client/1`: Get a client's socket using its PID.

    Example:

    ```elixir
    {:ok, _} = Chat.ClientsStateAgent.start_link([])
    ```
  """
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def add_client(pid, socket) do
    Agent.update(__MODULE__, fn clients ->
      Map.put(clients, pid, socket)
    end)
  end

  def remove_client(pid) do
    Agent.update(__MODULE__, fn clients ->
      Map.delete(clients, pid)
    end)
  end

  def get_clients do
    Agent.get(__MODULE__, fn clients -> clients end)
  end

  def get_client(pid) do
    Agent.get(__MODULE__, fn clients -> Map.get(clients, pid) end)
  end
end

defmodule Chat.ClientsStateAgent do
  use Agent

  # Initialize the agent with an empty map to store clients.
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  # Add a client with its PID to the agent.
  def add_client(pid, socket) do
    Agent.update(__MODULE__, fn clients ->
      Map.put(clients, pid, socket)
    end)
  end

  # Remove a client using its PID from the agent.
  def remove_client(pid) do
    Agent.update(__MODULE__, fn clients ->
      Map.delete(clients, pid)
    end)
  end

  # Get all client PIDs from the agent.
  def get_clients do
    Agent.get(__MODULE__, fn clients -> clients end)
  end

  # Get a client's socket using its PID from the agent.
  def get_client(pid) do
    Agent.get(__MODULE__, fn clients -> Map.get(clients, pid) end)
  end
end

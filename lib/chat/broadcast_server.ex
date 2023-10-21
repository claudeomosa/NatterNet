defmodule Chat.BroadcastServer do
  use GenServer

  @moduledoc """
    GenServer callbacks and logic to handle /NICK, /BC, /MSG, and /LIST commands
  """

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    :ets.new(:nicknames, [:set, :named_table])
    {:ok, nil}
  end

  def set_nickname(nickname, pid) do
    GenServer.call(__MODULE__, {:set_nickname, nickname, pid})
  end

  def remove_nickname(nickname) do
    GenServer.cast(__MODULE__, {:remove_nickname, nickname})
  end

  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  def send_message(nickname, message) do
    GenServer.cast(__MODULE__, {:send_message, nickname, message})
  end

  def get_all_nicknames() do
    :ets.tab2list(:nicknames)
    |> Enum.map(fn {nickname, _pid} -> nickname end)


  end

  def handle_cast({:broadcast, message}, state) do
    # Broadcast the message to all connected clients
    # {:noreply, state}
    Enum.each(:ets.tab2list(:nicknames), fn {_nickname, pid} ->
      send(pid, message)
    end)
    {:noreply, state}
  end

  def handle_cast({:send_message, nickname, message}, state) do
    # Send a private message to a specific client
    # {:noreply, state}
    case :ets.lookup(:nicknames, nickname) do
      [{_nickname, pid}] ->
        send(pid, message)
        {:noreply, state}
      _ ->
        IO.puts "Nickname #{nickname} not found"
        {:noreply, state}
    end
  end

  #####

  def handle_call({:set_nickname, nickname, pid}, _from, state) do
    case validate_nickname(nickname) do
      {:ok, valid_nickname} ->
        case :ets.lookup(:nicknames, valid_nickname) do
          [] ->
            :ets.insert(:nicknames, {valid_nickname, pid})
            {:reply, {:ok, valid_nickname}, state}
          _ ->
            IO.puts "Nickname #{valid_nickname} already taken"
            {:reply, {:error, "Nickname #{valid_nickname} already taken"}, state}
        end
      {:error, reason} ->
        IO.puts("Invalid nickname: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_cast({:remove_nickname, nickname}, state) do
    :ets.delete(:nicknames, nickname)
    {:noreply, state}
  end

  # def handle_cast({:broadcast, message}, state) do
  #   # Broadcast the message to all connected clients
  #   Enum.each(:ets.tab2list(:nicknames), fn {_nickname, pid} ->
  #     send(pid, message)
  #   end)
  #   {:noreply, state}
  # end

  # def handle_cast({:send_message, nickname, message}, state) do
  #   case :ets.lookup(:nicknames, nickname) do
  #     [{_nickname, pid}] ->
  #       send(pid, message)
  #       {:noreply, state}
  #     _ ->
  #       IO.puts "Nickname #{nickname} not found"
  #       {:noreply, state}
  #   end
  # end

  defp validate_nickname(nickname) do
    case Regex.scan(~r/\A[a-zA-Z][a-zA-Z0-9_]{0,11}\z/, nickname) do
      [[nickname]] when is_binary(nickname) ->
        {:ok, nickname}
      _ ->
        {:error, "Invalid nickname format"}
    end
  end


end

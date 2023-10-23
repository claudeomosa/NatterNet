defmodule Chat.BroadcastServer do
  @moduledoc """
    Chat Broadcast Server

    A GenServer module for managing user nicknames.

    ## Usage

    - Start the server with `Chat.BroadcastServer.start_link([])`.
    - Set nicknames with `Chat.BroadcastServer.set_nickname("username", pid)`.
    - Remove a nickname with `Chat.BroadcastServer.remove_nickname("username")`.

    ## Nickname Format

    User nicknames must start with a letter and can be up to 12 characters long, containing letters, numbers, and underscores.

  """
  use GenServer

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

  def get_nicknames_with_pids() do
    :ets.tab2list(:nicknames)
  end

  def get_pid_with_nickname(nickname) do
    :ets.lookup(:nicknames, nickname)
  end

  def get_all_nicknames() do
    :ets.tab2list(:nicknames)
    |> Enum.map(fn {nickname, _pid} -> nickname end)
  end

  def handle_cast({:remove_nickname, nickname}, state) do
    :ets.delete(:nicknames, nickname)
    {:noreply, state}
  end

  def handle_call({:set_nickname, nickname, pid}, _from, state) do
    case validate_nickname(nickname) do
      {:ok, valid_nickname} ->
        case :ets.lookup(:nicknames, valid_nickname) do
          [] ->
            :ets.insert(:nicknames, {valid_nickname, pid})
            {:reply, {:ok, valid_nickname}, state}

          _ ->
            IO.puts("Nickname #{valid_nickname} already taken")
            {:reply, {:error, "Nickname #{valid_nickname} already taken"}, state}
        end

      {:error, reason} ->
        IO.puts("Invalid nickname: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  defp validate_nickname(nickname) do
    case Regex.scan(~r/\A[a-zA-Z][a-zA-Z0-9_]{0,11}\z/, nickname) do
      [[nickname]] when is_binary(nickname) ->
        {:ok, nickname}

      _ ->
        {:error, "Invalid nickname format"}
    end
  end
end

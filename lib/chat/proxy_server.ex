defmodule Chat.ProxyServer do
  require Logger
  alias Chat.{BroadcastServer, ClientsStateAgent, TaskSupervisor}

  @moduledoc """
    This module has Logic to start the TCP server and handle client connections.
    It spawns proxy processes for each connected client by default on port 6666.
    It is responsible for validating and parsing client commands and communicating with the broadcast server (Chat.BroadcastServer).
  """

  defmodule State do
    defstruct [:port, :listen_socket, :nickname]
  end

  def accept(port \\ 6666) do
    {:ok, listen_socket} =
      :gen_tcp.listen(port, [:binary, active: false, packet: :line, reuseaddr: true])

    Logger.info("Listening on port #{port}")
    {:ok, _pid} = BroadcastServer.start_link([])

    initial_state = %State{port: port, listen_socket: listen_socket, nickname: nil}
    acceptor_loop(initial_state)
  end

  def acceptor_loop(state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)

    :gen_tcp.send(
      client_socket,
      "Welcome to the chat server!\nPlease set your nickname using the /NICK command.\n"
    )

    {:ok, client_pid} =
      Task.Supervisor.start_child(TaskSupervisor, fn -> serve(client_socket, state) end)

    ClientsStateAgent.add_client(client_pid, client_socket)
    :ok = :gen_tcp.controlling_process(client_socket, client_pid)

    acceptor_loop(state)
  end

  defp serve(socket, state) do
    socket |> read_line(state)
    serve(socket, state)
  end

  defp read_line(socket, state) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        Logger.info("Received: #{line}")

        if is_nil(state.nickname) do
          handle_nick(socket, line, state)
        else
          parse_command(socket, line, state)
        end

      {:error, :closed} ->
        Logger.info("Client disconnected")
        ClientsStateAgent.remove_client(self())
        BroadcastServer.remove_nickname(state.nickname)
        {:ok, _} = :gen_tcp.close(socket)
        serve(socket, state)

      {:error, reason} ->
        Logger.error("Error: #{reason}")
    end
  end

  defp parse_command(socket, line, state) do
    [command | args] = String.split(line, " ", trim: true)

    case String.trim(command) do
      "/LIST" ->
        case args do
          [] -> handle_list(socket)
          _ -> handle_list(socket)
        end

      "/BC" ->
        case args do
          [] -> send_error(socket, "Please provide a message to broadcast")
          ["\n"] -> send_error(socket, "Please provide a message to broadcast")
          _ -> handle_broadcast(socket, args, state)
        end

      "/MSG" ->
        case args do
          [] -> send_error(socket, "Please provide a nickname and a message")
          ["\n"] -> send_error(socket, "Please provide a nickname and a message")
          [_] -> send_error(socket, "Please provide a nickname and a message")
          _ -> handle_message(socket, hd(args), tl(args), state)
        end

      "/NICK" ->
        case args do
          [] -> send_error(socket, "Please provide a nickname")
          ["\n"] -> send_error(socket, "Please provide a nickname")
          _ -> handle_reset_nick(socket, args, state)
        end

      _ ->
        send_error(socket, "Invalid command: #{String.trim(command)}")
    end
  end

  defp handle_list(socket) do
    send_response(
      socket,
      "Online users: #{BroadcastServer.get_all_nicknames() |> Enum.join(", ")}"
    )
  end

  defp handle_nick(socket, line, state) do
    actions = String.split(line, " ", trim: true)

    if String.trim(hd(actions)) == "/NICK" and tl(actions) != [] do
      new_nickname = String.trim(tl(actions) |> hd())

      case BroadcastServer.get_all_nicknames() do
        nicknames ->
          case Enum.member?(nicknames, new_nickname) do
            true ->
              send_response(
                socket,
                "Nickname '#{new_nickname}' already taken. Please choose another nickname."
              )

              :ok

            false ->
              case BroadcastServer.set_nickname(new_nickname, self()) do
                {:ok, nickname} ->
                  send_response(socket, "Nickname set to '#{nickname}'")
                  updated_state = %{state | nickname: nickname}
                  serve(socket, updated_state)

                {:error, reason} ->
                  send_response(socket, "Error: #{reason}")
              end
          end
      end
    else
      send_response(socket, "Please set your nickname using the /NICK command.")
      :ok
    end
  end

  defp handle_reset_nick(socket, args, state) do
    new_nickname = String.trim(hd(args))

    case BroadcastServer.get_all_nicknames() do
      nicknames ->
        case Enum.member?(nicknames, new_nickname) do
          true ->
            send_response(
              socket,
              "Nickname '#{new_nickname}' already taken. Please choose another nickname."
            )

            :ok

          false ->
            case BroadcastServer.set_nickname(new_nickname, self()) do
              {:ok, nickname} ->
                send_response(socket, "Nickname Changed to '#{nickname}'")
                BroadcastServer.remove_nickname(state.nickname)
                updated_state = %{state | nickname: nickname}
                serve(socket, updated_state)

              {:error, reason} ->
                send_response(socket, "Error: #{reason}")
            end
        end
    end
  end

  defp handle_broadcast(socket, message, state) do
    message = extract_message(message)

    case message do
      "" -> send_error(socket, "Please provide a message to broadcast")
      _ -> handle_broadcast_message(socket, message, state)
    end
  end

  defp handle_message(socket, recipient_nickname, message, state) do
    message = extract_message(message)

    case message do
      "" -> send_error(socket, "Please provide a message to send")
      _ -> handle_private_message(socket, recipient_nickname, message, state)
    end
  end

  defp send_error(socket, message) do
    :gen_tcp.send(socket, "Error: #{message}\n")
  end

  defp send_response(socket, response) do
    :gen_tcp.send(socket, response <> "\n")
  end

  defp extract_message(message) do
    message
    |> Enum.map(fn word -> String.trim(word) end)
    |> Enum.reject(fn word -> word == "" end)
    |> Enum.join(" ")
  end

  defp handle_broadcast_message(socket, message, state) do
    Logger.info("Broadcasting: #{message}")
    BroadcastServer.broadcast(message)

    Enum.each(ClientsStateAgent.get_clients(), fn {_client_pid, client_socket} ->
      send_response(client_socket, "Broadcast from `#{state.nickname}`: #{message}")
    end)

    serve(socket, state)
  end

  def handle_private_message(socket, recipient_nickname, message, state) do
    Logger.info("Sending message to #{recipient_nickname}: #{message}")

    case BroadcastServer.get_pid_with_nickname(recipient_nickname) do
      [{_nickname, pid}] ->
        send_response(socket, "Message sent to `#{recipient_nickname}`: #{message}")

        send_response(
          ClientsStateAgent.get_client(pid),
          "Private Message from `#{state.nickname}`: #{message}"
        )

        serve(socket, state)

      _ ->
        send_response(socket, "Nickname '#{recipient_nickname}' not found")
        serve(socket, state)
    end
  end
end

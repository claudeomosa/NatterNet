# defmodule Chat.BroadcastServer do
#   use GenServer

#   defmodule State do
#     defstruct users: %{}, nicks: %{}
#   end

#   def start_link(_) do
#     GenServer.start_link(__MODULE__, %State{})
#   end

#   # Command handling
#   def handle_cast({:command, socket, message}, state) do
#     [command | args] = String.split(message, " ", trim: true)

#     case command do
#       "/LIST" -> handle_list(socket, state)
#       "/NICK" -> handle_nick(socket, hd(args), state)
#       "/BC" -> handle_broadcast(socket, args, state)
#       "/MSG" -> handle_message(socket, hd(args), tl(args), state)
#       _ -> send_error(socket, "Invalid command: #{command}")
#     end

#     {:noreply, state}
#   end

#   # Handle the /LIST command
#   defp handle_list(socket, state) do
#     users = Map.keys(state.users)
#     response = "Online users: #{Enum.join(users, ', ')}"
#     send_response(socket, response)
#   end

#   # Handle the /NICK command
#   defp handle_nick(socket, nick, state) when is_valid_nickname(nick) do
#     if Map.has_key?(state.nicks, nick) do
#       send_error(socket, "Nickname '#{nick}' is already in use.")
#     else
#       {:ok, _} = send_response(socket, "Nickname set to '#{nick}'.")
#       {:noreply, update_nick(socket, nick, state)}
#     end
#   end

#   defp handle_nick(socket, _, state) do
#     send_error(socket, "Invalid nickname format. It must start with an alphabet and contain only alphanumeric or underscores, up to 12 characters.")
#   end

#   # Handle the /BC command
#   defp handle_broadcast(socket, message, state) do
#     response = "Broadcast: #{message}"
#     send_broadcast(socket, response, state)
#   end

#   # Handle the /MSG command
#   defp handle_message(socket, nick, message, state) do
#     if Map.has_key?(state.nicks, nick) do
#       send_message(nick, message, state)
#     else
#       send_error(socket, "User '#{nick}' not found.")
#     end
#   end

#   # Update the user's nickname
#   defp update_nick(socket, nick, state) do
#     user_pid = Process.whereis(socket)
#     new_state = %State{
#       users: Map.update!(state.users, user_pid, [nick], &(&1)),
#       nicks: Map.update!(state.nicks, nick, [user_pid], &(&1))
#     }
#     {:ok, _} = GenServer.cast(__MODULE__, {:register_user, user_pid})
#     new_state
#   end

#   # Handle client registration
#   def handle_cast({:register_user, user_pid}, state) do
#     new_state = %State{
#       state | users: Map.update!(state.users, user_pid, [], &(&1))
#     }
#     {:noreply, new_state}
#   end

#   # Handle client disconnection
#   def handle_cast({:unregister_user, user_pid}, state) do
#     nicks = Map.get(state.users, user_pid) || []
#     new_state = %State{
#       state | users: Map.delete(state.users, user_pid),
#               nicks: Enum.fold(nicks, state.nicks, fn nick, nicks -> Map.update(nicks, nick, &List.delete(&1, user_pid)) end)
#     }
#     {:noreply, new_state}
#   end

#   # Check if a nickname is valid
#   defp is_valid_nickname(nick) when is_binary(nick) and String.match?(nick, ~r/^[a-zA-Z][\w]{0,11}$/) do
#     true
#   end

#   defp is_valid_nickname(_), do: false

#   # Send a response to a client
#   defp send_response(socket, message) do
#     send(socket, {:response, message})
#     {:ok, _} = GenServer.cast(__MODULE__, {:register_user, Process.whereis(socket)})
#   end

#   # Send a broadcast message to all users
#   defp send_broadcast(sender, message, state) do
#     user_pids = Map.keys(state.users) |> Enum.filter(&(&1 != sender))
#     for user_pid <- user_pids do
#       send(user_pid, {:response, message})
#     end
#   end

#   # Send a private message to a user
#   defp send_message(nick, message, state) do
#     user_pids = Map.get(state.nicks, nick) || []
#     for user_pid <- user_pids do
#       send(user_pid, {:response, "Private message from #{Process.whereis(self())}: #{message}"})
#     end
#   end

#   # Send an error message to a client
#   defp send_error(socket, message) do
#     send(socket, {:response, "Error: #{message}"})
#   end
# end

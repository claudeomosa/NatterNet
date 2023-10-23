package client;

import java.io.*;
import java.net.Socket;
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        String host = "localhost"; // Change to your server's host
        int port = 6666; // Change to your server's port

        try (Socket socket = new Socket(host, port);
             BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
             BufferedWriter out = new BufferedWriter(new OutputStreamWriter(socket.getOutputStream()));
            //  BufferedReader userInput = new BufferedReader(new InputStreamReader(System.in)))
            Scanner userInput = new Scanner(System.in)) {

            System.out.println("Connected to the Elixir chat server");

            // Continuously read user input and send it to the server
            while (true) {
                // Read and display the server's response
                String response = in.readLine();
                if (response != null) {
                    System.out.println("Server Response: " + response);
                }

                String userCommand = userInput.nextLine();
                if (userCommand == null) {
                    // End-of-file, exit the client
                    break;
                }

                // Send the user's command to the server
                out.write(userCommand);
                out.newLine(); // Add a newline character
                out.flush(); // Flush the output stream
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}

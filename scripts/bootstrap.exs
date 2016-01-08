#!/usr/bin/env elixir --hidden --sname bootstrap@localhost

# TODO: This wants to be an escript
# TODO: Pass in node identifier
remote_node = :cog_dev@localhost
Node.connect remote_node

IO.puts "Bootstrapping your Cog system..."

case :rpc.call(remote_node, Cog.Bootstrap, :is_bootstrapped?, []) do
  true ->
    IO.puts "The system has already been bootstrapped!"
    exit {:shutdown, 1}
  false ->
    IO.puts "Bootstrapping your system."
    {:ok, admin} = :rpc.call(remote_node, Cog.Bootstrap, :bootstrap, [])

    IO.puts """
    Log into your COG system using the following credentials:

    username: #{admin.username}
    password: #{admin.password}

    This password was randomly generated for you.

    Keep it secret; keep it safe!
    """
end

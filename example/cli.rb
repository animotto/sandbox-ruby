#!/usr/bin/env ruby

# frozen_string_literal: true

require 'sandbox'

# Create a new shell instance
shell = Sandbox::Shell.new(
  prompt: ' CLI> ',
  banner: 'Example banner',
  # You can disable built-in commands
  # builtin_help: false,
  # builtin_path: false,
  # builtin_quit: false
)

# Command in the root context
command_counter = shell.add_command(
  :counter,
  description: 'Counter',
  params: ['<n>'] # Mandatory parameter
) do |shell, context, tokens|
  n = tokens[1].to_i
  n.times { |i| shell.print("#{i} ") }
  shell.puts
end

# Auto completion for the command
command_counter.completion do |shell, tokens, line|
  (1..10).to_a.map(&:to_s)
end

# Any command in the root context can be global (visible in any context)
shell.add_command(
  :echo,
  description: 'Echo',
  params: ['[text]'], # Optional parameter
  global: true
) do |shell, context, tokens|
  shell.puts(tokens[1..].join(' '))
end

# Additional context in the root context
context_fruit = shell.add_context(:fruit, description: 'Fruits')
context_fruit.add_command(
  :apple,
  description: 'Apple'
) do |shell, context, tokens|
  shell.puts("I'm and apple!")
end

# You can define aliases for your command
context_fruit.add_command(
  :orange,
  description: 'Orange or tangerine',
  aliases: [:tangerine]
) do |shell, context, tokens|
  shell.puts("Sometimes i'm an orange or a tangerine")
end

# You can use search path for context and command
shell.add_context(:vegetable, description: 'Vegetables')
shell.context(:vegetable).add_context(:tasty)
shell.context(:vegetable, :tasty).add_command(:potato) do |shell, context, tokens|
  shell.puts("Yammy!")
end
shell.command(:vegetable, :tasty, :potato).completion do |shell, tokens, line|
  ['one', 'two']
end

# You can remove a context or command at any time
shell.add_context(:useless)
shell.context(:useless).add_command(:test)
shell.context(:useless).remove_command(:test)
shell.remove_context(:useless)

# Run the shell
shell.run

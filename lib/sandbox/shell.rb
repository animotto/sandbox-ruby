# frozen_string_literal: true

require 'readline'

module Sandbox
  ##
  # Shell
  class Shell
    DEFAULT_PROMPT = '> '
    DEFAULT_BANNER = 'Sandbox shell'

    attr_accessor :prompt, :banner, :root, :path

    def initialize(input = $stdin, output = $stdout, **options)
      @input = input
      @output = output
      @history = options.fetch(:history, true)

      @prompt = options.fetch(:prompt, DEFAULT_PROMPT)
      @banner = options.fetch(:banner, DEFAULT_BANNER)

      @root = Context.new(:root)
      @path = []
      @running = false

      add_command_help
      add_command_quit
      add_command_pwd
    end

    def run
      puts(@banner)
      @running = true
      while @running
        raise ShellError, "Root context doesn't exist" if @root.nil?

        line = Readline.readline("#{formatted_path}#{DEFAULT_PROMPT}", @history)
        break if line.nil?

        line.strip!
        next if line.empty?

        tokens = line.split(/\s+/)
        tokens[0].downcase!
        @root.context(*@path).exec(self, tokens)
      end
    end

    def stop
      @running = false
    end

    def print(data)
      @output.print(data)
    end

    def puts(data = '')
      @output.puts(data)
    end

    def formatted_path
      "/#{@path.join('/')}"
    end

    private

    def add_command_help
      @root.add_command(:help, aliases: ['?'], global: true, description: 'This help') do |shell|
        list = []
        list += @root.commands.select(&:global?) unless @path.empty?
        list += @root.context(*@path).commands
        list.sort! { |a, b| a.name <=> b.name }
        list = @root.context(*@path).contexts.sort { |a, b| a.name <=> b.name } + list
        list.each do |c|
          name = c.instance_of?(Context) ? "[#{c.name}]" : c.name
          shell.puts(
            format(
              ' %<name>-15s%<description>s',
              name: name,
              description: c.description
            )
          )
        end
      end
    end

    def add_command_quit
      @root.add_command(:quit, aliases: [:exit], global: true, description: 'Quit') do |shell|
        shell.stop
      end
    end

    def add_command_pwd
      @root.add_command(:pwd, global: true, description: 'Show path') do |shell|
        shell.puts(shell.formatted_path)
      end
    end
  end

  ##
  # ShellError
  class ShellError < StandardError; end
end

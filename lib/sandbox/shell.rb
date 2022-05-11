# frozen_string_literal: true

require 'readline'

module Sandbox
  ##
  # Shell
  class Shell
    DEFAULT_PROMPT = '> '
    DEFAULT_BANNER = 'Sandbox shell'

    attr_accessor :prompt, :banner, :root, :path

    ##
    # Creates a new shell
    def initialize(input = $stdin, output = $stdout, **options)
      @input = input
      @output = output
      @history = options.fetch(:history, true)

      @prompt = options.fetch(:prompt, DEFAULT_PROMPT)
      @banner = options.fetch(:banner, DEFAULT_BANNER)

      @root = Context.new(:root, self)
      @path = []
      @running = false
      @reading = false

      add_command_help if options.fetch(:builtin_help, true)
      add_command_quit if options.fetch(:builtin_quit, true)
      add_command_path if options.fetch(:builtin_path, true)
    end

    ##
    # Runs the shell
    def run
      puts(@banner)
      Readline.completion_proc = proc { |line| completion_proc(line) }
      @running = true
      while @running
        raise ShellError, "Root context doesn't exist" if @root.nil?

        begin
          line = readline("#{formatted_path}#{@prompt}", @history)
          if line.nil?
            puts
            break
          end

          line.strip!
          next if line.empty?

          tokens = split_tokens(line)
          @root.context(*@path).exec(self, tokens)
        rescue Interrupt
          @output.print("\e[0G\e[J")
        end
      end
    end

    ##
    # Reads and returns a line
    def readline(prompt, history)
      @reading = true
      line = Readline.readline(prompt, history)
      Readline::HISTORY.pop if line&.strip&.empty?
      Readline::HISTORY.pop if Readline::HISTORY.length >= 2 && Readline::HISTORY[-2] == line
      @reading = false
      line
    end

    ##
    # Stops the shell
    def stop
      @running = false
    end

    ##
    # Prints data
    def print(data)
      @output.print(data)
    end

    ##
    # Prints data with a line at the end
    def puts(data = '')
      @output.print("\e[0G\e[J") if @reading
      @output.puts(data)
      Readline.refresh_line if @reading
    end

    ##
    # Returns the current formatted path
    def formatted_path
      "/#{@path.join('/')}"
    end

    private

    ##
    # Returns an array of tokens from the line
    def split_tokens(line)
      tokens = line.split(/\s+/)
      tokens.first&.downcase!
      tokens
    end

    ##
    # Readline completion proc
    def completion_proc(line)
      tokens = split_tokens(Readline.line_buffer)

      commands = []
      commands += @root.context(*@path).contexts
      commands += @root.context(*@path).commands
      commands += @root.commands.select(&:global?) unless @path.empty?

      command = commands.detect { |c| c.instance_of?(Command) && c.match?(tokens.first) }
      list = commands.map(&:name)
      list = command.completion_proc&.call(self, tokens, line) unless command.nil?

      list&.grep(/^#{Regexp.escape(line)}/)
    end

    # Built-in help command
    def add_command_help
      @root.add_command(
        :help,
        aliases: ['?'],
        description: 'This help',
        global: true
      ) do |shell, _context, tokens|
        list = []
        list += @root.commands.select(&:global?) unless @path.empty?
        list += @root.context(*@path).commands
        list.sort! { |a, b| a.name <=> b.name }
        list = @root.context(*@path).contexts.sort { |a, b| a.name <=> b.name } + list

        unless tokens[1].nil?
          cmd = list.detect { |c| c.instance_of?(Command) && c.match?(tokens[1]) }
          if cmd.nil?
            shell.puts("Unknown command #{tokens[1]}")
            next
          end

          shell.puts(cmd.description) unless cmd.description.nil?
          shell.print(' ')
          cmd.print_usage
          next
        end

        list.each do |c|
          if c.instance_of?(Context)
            shell.puts(
              format(
                ' %<name>-25s %<description>s',
                name: "[#{c.name}]",
                description: c.description
              )
            )
            next
          end

          shell.puts(
            format(
              ' %<name>-25s %<description>s',
              name: "#{c.name} #{c.params.keys.join(' ')}",
              description: c.description
            )
          )
        end
      end
    end

    # Built-in quit command
    def add_command_quit
      @root.add_command(
        :quit,
        aliases: [:exit],
        description: 'Quit',
        global: true
      ) do |shell|
        shell.stop
      end
    end

    # Built-in path command
    def add_command_path
      @root.add_command(
        :path,
        description: 'Show path',
        global: true
      ) do |shell|
        shell.puts(shell.formatted_path)
      end
    end
  end

  ##
  # Shell error
  class ShellError < StandardError; end
end

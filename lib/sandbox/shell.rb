# frozen_string_literal: true

require 'readline'
require 'shellwords'

CONFIRM_LIST = %i[y n].freeze

module Sandbox
  ##
  # Shell
  class Shell
    DEFAULT_PROMPT = '> '
    DEFAULT_BANNER = 'Sandbox shell'

    attr_reader :root
    attr_accessor :prompt, :banner, :path

    ##
    # Creates a new shell
    def initialize(
      input = $stdin,
      output = $stdout,
      prompt: DEFAULT_PROMPT,
      banner: DEFAULT_BANNER,
      history: true,
      builtin_help: true,
      builtin_quit: true,
      builtin_path: true
    )
      @input = input
      @output = output
      @history = history

      @prompt = prompt
      @banner = banner

      @root = Context.new(:root, self)
      @path = []
      @running = false
      @reading = false

      add_command_help if builtin_help
      add_command_quit if builtin_quit
      add_command_path if builtin_path
    end

    ##
    # Runs the shell
    def run
      puts(@banner)
      Readline.completion_proc = proc { |line| completion_proc(line) }
      @running = true
      while @running
        begin
          line = readline("#{formatted_path}#{@prompt}", @history)
          if line.nil?
            puts
            break
          end

          line.strip!
          next if line.empty?

          exec(line)
        rescue ShellError => e
          puts(e)
          retry
        rescue Interrupt
          print("\e[0G\e[J")
        end
      end
    end

    ##
    # Executes command
    def exec(line)
      tokens = split_tokens(line)
      @root.context(*@path).exec(self, tokens)
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
    # Requests the confirmation
    def confirm(prompt, default: :n)
      list = CONFIRM_LIST.join('/')
      raise ShellError, "Default should be #{list}" unless CONFIRM_LIST.include?(default)

      prompt = "#{prompt} (#{list}) [#{default}] "
      loop do
        line = readline(prompt, @history)

        if line.nil?
          puts
          return
        end

        line.strip!
        line.downcase!
        return default == CONFIRM_LIST.first if line.empty?

        next unless CONFIRM_LIST.map(&:to_s).include?(line)

        return line == CONFIRM_LIST.first.to_s
      end
    end

    ##
    # Returns the current formatted path
    def formatted_path
      "/#{@path.join('/')}"
    end

    ##
    # Adds a new context to the root context
    def add_context(name, **options)
      @root.add_context(name, **options)
    end

    ##
    # Removes a context from the root context
    def remove_context(name)
      @root.remove_context(name)
    end

    ##
    # Adds a command to the root context
    def add_command(name, **options, &block)
      @root.add_command(name, **options, &block)
    end
    ##

    # Removes a command from the root context
    def remove_command(name)
      @root.remove_command(name)
    end

    ##
    # Returns a context by the path from the root context
    def context(*path)
      @root.context(*path)
    end

    ##
    # Returns a command by the path from the root context
    def command(*path)
      @root.command(*path)
    end

    private

    ##
    # Returns an array of tokens from the line
    def split_tokens(line)
      tokens = line.shellsplit
      tokens.first&.downcase!
      tokens
    rescue ArgumentError => e
      raise ShellError, e
    end

    ##
    # Readline completion proc
    def completion_proc(line)
      tokens = split_tokens(Readline.line_buffer)

      context = @root.context(*@path)
      commands = []
      commands += context.contexts
      commands += context.commands
      commands += @root.commands.select(&:global?) unless @path.empty?

      command = commands.detect { |c| c.instance_of?(Command) && c.match?(tokens.first) }
      list = commands.map(&:name)
      list = command.completion_proc&.call(line, tokens, self, context, command) unless command.nil?

      list&.grep(/^#{Regexp.escape(line)}/)
    end

    # Built-in help command
    def add_command_help
      @root.add_command(
        :help,
        aliases: ['?'],
        description: 'This help',
        global: true
      ) do |tokens, shell|
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
      ) do |_tokens, shell|
        shell.stop
      end
    end

    # Built-in path command
    def add_command_path
      @root.add_command(
        :path,
        description: 'Show path',
        global: true
      ) do |_tokens, shell|
        shell.puts(shell.formatted_path)
      end
    end
  end

  ##
  # Shell error
  class ShellError < StandardError; end
end

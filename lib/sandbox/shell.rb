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
      @reading = false

      add_command_help if options.fetch(:builtin_help, true)
      add_command_quit if options.fetch(:builtin_quit, true)
      add_command_pwd if options.fetch(:builtin_pwd, true)
    end

    def run
      puts(@banner)
      Readline.completion_proc = proc { |line| completion_proc(line) }
      @running = true
      while @running
        raise ShellError, "Root context doesn't exist" if @root.nil?

        @reading = true
        line = Readline.readline("#{formatted_path}#{@prompt}", @history)
        @reading = false
        break if line.nil?

        line.strip!
        if line.empty?
          Readline::HISTORY.pop
          next
        end

        tokens = split_tokens(line)
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
      @output.print("\e[0G\e[J") if @reading
      @output.puts(data)
      Readline.refresh_line if @reading
    end

    def formatted_path
      "/#{@path.join('/')}"
    end

    private

    def split_tokens(line)
      tokens = line.split(/\s+/)
      tokens.first&.downcase!
      tokens
    end

    def completion_proc(line)
      tokens = split_tokens(Readline.line_buffer)

      commands = []
      commands += @root.context(*@path).contexts
      commands += @root.context(*@path).commands
      commands += @root.commands.select(&:global?) unless @path.empty?

      command = commands.detect { |c| c.name.to_s == tokens.first }
      list = commands.map(&:name)
      list = command.completion_proc&.call(self, tokens, line) unless command.nil?

      list&.grep(/^#{Regexp.escape(line)}/)
    end

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
  # Shell error
  class ShellError < StandardError; end
end

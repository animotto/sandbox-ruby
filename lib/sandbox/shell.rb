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
    end

    def run
      puts(@banner)
      @running = true
      while @running
        raise ShellError, "Root context doesn't exist" if @root.nil?

        line = Readline.readline("#{formated_path}#{DEFAULT_PROMPT}", @history)
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

    def formated_path
      "/#{@path.join('/')}"
    end
  end

  ##
  # ShellError
  class ShellError < StandardError; end
end

# frozen_string_literal: true

module Sandbox
  ##
  # Command
  class Command
    attr_reader :completion_proc, :aliases, :params
    attr_accessor :name, :description, :global

    ##
    # Creates a new command
    def initialize(name, shell, context, block, **options)
      @name = name.to_sym
      @shell = shell
      @context = context
      @block = block
      @description = options[:description]
      @global = options[:global]
      @aliases = options[:aliases]&.map(&:to_sym)

      @params = {}
      params = options[:params]
      params&.each do |param|
        param = param.strip
        if param.start_with?('[') && param.end_with?(']')
          @params[param] = false
        elsif param.start_with?('<') && param.end_with?('>')
          @params[param] = true
        end
      end

      @completion_proc = nil
    end

    ##
    # Executes the command
    def exec(tokens)
      mandatory = @params.count { |_, v| v }
      if mandatory > (tokens.length - 1)
        print_usage
        return
      end

      @block&.call(tokens, @shell, @context, self)
    end

    ##
    # Sets a block for the readline auto completion
    def completion(&block)
      @completion_proc = block
    end

    ##
    # Returns true if the command is global
    def global?
      @global
    end

    ##
    # Returns the string representation of the command
    def to_s
      @name.to_s
    end

    ##
    # Returns true if the name matches the command name or alias
    def match?(name)
      name = name&.to_sym
      @name == name || @aliases&.include?(name)
    end

    ##
    # Prints command usage
    def print_usage
      @shell.print("Usage: #{@name} ")
      @shell.puts(params.keys.join(' '))
    end
  end
end

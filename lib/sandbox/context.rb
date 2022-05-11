# frozen_string_literal: true

module Sandbox
  ##
  # Context
  class Context
    INVALID_CHARS = [
      '/',
      '.',
      '\s'
    ].freeze

    attr_reader :contexts, :commands, :completion_proc
    attr_accessor :name, :description

    ##
    # Creates a new context
    def initialize(name, shell, **options)
      @name = name.to_sym
      @shell = shell
      @description = options[:description]

      @contexts = []
      @commands = []
      @completion_proc = nil
    end

    ##
    # Adds a new context to the current context
    def add_context(name, **options)
      raise ContextError, "Context #{name} contains invalid characters" if invalid_chars?(name)

      name = name.downcase.to_sym
      raise ContextError, "Context #{name} already exists in context #{self}" if context?(name)
      raise ContextError, "Command #{name} already exists in context #{self}" if command?(name)

      context = Context.new(name, @shell, **options)
      @contexts << context
      context
    end

    ##
    # Removes a context from the current context
    def remove_context(name)
      name = name.downcase.to_sym
      raise ContextError, "Context #{name} doesn't exists in context #{self}" unless context?(name)

      @contexts.delete_if { |c| c.name == name }
    end

    ##
    # Adds a command to the current context
    def add_command(name, **options, &block)
      raise ContextError, "Command #{name} contains invalid characters" if invalid_chars?(name)

      name = name.downcase.to_sym
      raise ContextError, "Context #{name} already exists in context #{self}" if context?(name)
      raise ContextError, "Command #{name} already exists in context #{self}" if command?(name)

      command = Command.new(name, @shell, self, block, **options)
      @commands << command
      command
    end

    ##
    # Removes a command from the current context
    def remove_command(name)
      name = name.downcase.to_sym
      raise ContextError, "Command #{name} doesn't exists in context #{self}" unless command?(name)

      @commands.delete_if { |c| c.match?(name) }
    end

    ##
    # Executes the command in the current context
    def exec(shell, tokens)
      path = tokens.first.split('/')
      if path.empty?
        shell.path.clear
        return
      end

      path_prev = shell.path.clone
      shell.path.clear if tokens.first.start_with?('/')
      if path.length > 1
        path[0..-2].each do |p|
          if p == '..'
            shell.path.pop
            next
          end

          shell.path << p.to_sym unless p.empty?
        end
      end

      if path.last == '..'
        shell.path.pop
        return
      end

      current = shell.root.context(*shell.path)
      if current.nil?
        shell.puts("Unrecognized command: #{tokens.first}")
        shell.path = path_prev
        return
      end

      current.contexts.each do |context|
        next unless context.name.to_s == path.last

        shell.path << context.name
        return nil
      end

      commands = []
      commands += current.commands
      commands += shell.root.commands.select(&:global?)
      commands.each do |command|
        next unless command.match?(path.last)

        command.exec(tokens)
        shell.path = path_prev
        return nil
      end

      shell.puts("Unrecognized command: #{tokens.first}")
      shell.path = path_prev
    end

    ##
    # Returns a context by the path
    def context(*path)
      return self if path.empty?

      path.map!(&:downcase)
      path.map!(&:to_sym)
      context = nil
      current = self
      path.each do |p|
        context = current.contexts.detect { |c| c.name == p }
        break if context.nil?

        current = context
      end
      context
    end

    ##
    # Returns the string representation of the context
    def to_s
      @name.to_s
    end

    private

    ##
    # Returns true if the context exists in the current context
    def context?(name)
      @contexts.any? { |c| c.name == name }
    end

    ##
    # Returns true if the command exists in the current context
    def command?(name)
      @commands.any? { |c| c.match?(name) }
    end

    ##
    # Returns true if the name contains invalid characters
    def invalid_chars?(name)
      name =~ /[#{INVALID_CHARS.join}]/
    end
  end

  ##
  # Context error
  class ContextError < StandardError; end
end

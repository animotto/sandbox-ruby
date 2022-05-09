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

    def initialize(name, **options)
      @name = name.to_sym
      @description = options[:description]

      @contexts = []
      @commands = []
      @completion_proc = nil
    end

    def add_context(name, **options)
      raise ContextError, "Context #{name} contains invalid characters" if name =~ /[#{INVALID_CHARS.join}]/

      name = name.downcase.to_sym
      commands = @contexts.select { |c| c.name == name }
      raise ContextError, "Context #{name} already exists in context #{self}" unless commands.empty?

      context = Context.new(name, **options)
      @contexts << context
      context
    end

    def remove_context(name)
      name = name.downcase.to_sym
      commands = @contexts.select { |c| c.name == name }
      raise ContextError, "Context #{name} doesn't exists in context #{self}" if commands.empty?

      @contexts.delete_if { |c| c.name == name }
    end

    def add_command(name, **options, &block)
      raise ContextError, "Command #{name} contains invalid characters" if name =~ /[#{INVALID_CHARS.join}]/

      name = name.downcase.to_sym
      commands = @commands.select { |c| c.name == name }
      raise ContextError, "Command #{name} already exists in context #{self}" unless commands.empty?

      command = Command.new(name, block, **options)
      @commands << command
      command
    end

    def remove_command(name)
      name = name.downcase.to_sym
      commands = @commands.select { |c| c.name == command.name }
      raise ContextError, "Command #{name} doesn't exists in context #{self}" if commands.empty?

      @commands.delete_if { |c| c.name == name }
    end

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
        next unless command.name.to_s == path.last || command.aliases&.detect { |a| a.to_s == path.last }

        command.exec(shell, self, tokens)
        shell.path = path_prev
        return nil
      end

      shell.puts("Unrecognized command: #{tokens.first}")
      shell.path = path_prev
    end

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

    def to_s
      @name.to_s
    end
  end

  ##
  # Context error
  class ContextError < StandardError; end
end

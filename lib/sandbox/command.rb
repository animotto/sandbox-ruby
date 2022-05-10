# frozen_string_literal: true

module Sandbox
  ##
  # Command
  class Command
    attr_reader :completion_proc, :aliases, :params
    attr_accessor :name, :description, :global

    def initialize(name, block, **options)
      @name = name.to_sym
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

    def exec(shell, context, tokens)
      mandatory = @params.count { |_, v| v }
      if mandatory > (tokens.length - 1)
        shell.print("Usage: #{@name} ")
        shell.puts(params.keys.join(' '))
        return
      end

      @block&.call(shell, context, tokens)
    end

    def completion(&block)
      @completion_proc = block
    end

    def global?
      @global
    end

    def to_s
      @name.to_s
    end
  end
end

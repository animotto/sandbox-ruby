# frozen_string_literal: true

module Sandbox
  ##
  # Command
  class Command
    attr_reader :completion_proc
    attr_accessor :name, :description, :global, :aliases

    def initialize(name, block, **options)
      @name = name.to_sym
      @block = block
      @description = options[:description]
      @global = options[:global]
      @aliases = options[:aliases]&.map(&:to_sym)

      @completion_proc = nil
    end

    def exec(shell, context, tokens)
      @block.call(shell, context, tokens)
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

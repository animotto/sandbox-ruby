# frozen_string_literal: true

require 'sandbox'

shell = Sandbox::Shell.new

RSpec.describe Sandbox::Context do
  it 'Creates a new context' do
    context_name = :test
    context_description = 'Test context'

    context = described_class.new(
      context_name,
      shell,
      description: context_description
    )

    expect(context.name).to eq(context_name)
    expect(context.description).to eq(context_description)
  end

  it 'Adds a new context to the current context' do
    context = described_class.new(:test, shell)

    context_name = :foo
    expect(context.add_context(context_name)).to be_a(described_class)
    expect(context.contexts.detect { |c| c.name == context_name }).not_to be_nil

    context_name = 'bar'
    expect(context.add_context(context_name)).to be_a(described_class)
    expect(context.contexts.detect { |c| c.name == context_name.to_sym }).not_to be_nil

    context_name = '/foo'
    expect { context.add_context(context_name) }.to raise_error(Sandbox::ContextError)

    context_name = :foo
    expect { context.add_context(context_name) }.to raise_error(Sandbox::ContextError)
  end

  it 'Removes a context from the current context' do
    context = described_class.new(:test, shell)

    context.add_context(:foo)
    context.remove_context(:foo)
    expect(context.contexts.detect { |c| c.name == context_name.to_sym }).to be_nil

    expect { context.remove_context(:foo) }.to raise_error(Sandbox::ContextError)
  end
end

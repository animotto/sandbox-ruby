# frozen_string_literal: true

require_relative 'lib/sandbox/version'

Gem::Specification.new do |s|
  s.name = 'sandbox-ruby'
  s.version = Sandbox::VERSION
  s.license = 'MIT'
  s.summary = 'Sandbox shell library for Ruby'
  s.authors = ['anim']
  s.email = 'me@telpart.ru'
  s.files = Dir['lib/**/*.rb']
  s.homepage = 'https://github.com/animotto/sandbox-ruby'
  s.required_ruby_version = '>= 2.7'
end

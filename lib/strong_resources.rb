require 'action_controller'
require 'stronger_parameters'

require "strong_resources/version"
require "strong_resources/configuration"
require "strong_resources/strong_resource"
require "strong_resources/controller/mixin"

if defined?(JsonapiErrorable)
  require "strong_resources/exception_handler"
end

module StrongResources
  class UnregisteredResource < StandardError
    def initialize(name)
      @name = name
    end

    def message
      "Resource with name #{@name} not registered"
    end
  end

  class UnregisteredType < StandardError
    def initialize(type)
      @type = type
    end

    def message
      <<-MSG
Type "#{@type}" was not found!

This is the right-hand side of your strong_resource attributes.

See the list of default types, and directions on how to register custom
types, here: https://jsonapi-suite.github.io/strong_resources/#default-types
      MSG
    end
  end

  def self.configure(&blk)
    config.instance_eval(&blk)
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.find(name)
    found = config.strong_resources[name]
    raise UnregisteredResource.new(name) unless found
    found
  end

  def self.type_for_param(name)
    found = config.strong_params[name]
    raise UnregisteredType.new(name) unless found
    found[:type]
  end
end

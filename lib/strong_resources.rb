require 'stronger_parameters'

require "strong_resources/version"
require "strong_resources/configuration"
require "strong_resources/strong_resource"
require "strong_resources/controller/mixin"

module StrongResources
  class UnregisteredResource < StandardError
    def initialize(name)
      @name = name
    end

    def message
      "Resource with name #{@name} not registered"
    end
  end

  class UnregisteredParam < StandardError
    def initialize(name)
      @name = name
    end

    def message
      "Parameter with name #{@name} not registered"
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
    found = config.strong_params[name][:type]
    raise UnregisteredParam.new(name) unless found
    found
  end
end

require 'active_model/railtie'

module ActiveModel
  class Railtie < Rails::Railtie
    generators do |app|
      Rails::Generators.configure! app.config.generators

      require_relative '../generators/model_override'
    end
  end
end

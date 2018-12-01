require "rails/generators"
require "rails/generators/rails/model/model_generator"

module Rails
  module Generators
    class ModelGenerator
      hook_for :strong_resource, type: :boolean, default: true do |generator|
        invoke generator, [name.singularize] + attributes.map { |attribute| "#{attribute.name}:#{attribute.type}" }
      end
    end
  end
end

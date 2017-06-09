module StrongResources
  module Controller
    module Mixin
      def self.included(klass)
        klass.class_eval do
          extend ClassMethods
          class << self
            attr_accessor :_strong_resources
          end
        end
      end

      # TODO: refactor
      def apply_strong_params
        deserializer = deserialized_params

        unless deserializer.attributes.respond_to?(:permit)
          deserializer.attributes = ActionController::Parameters.new(deserializer.attributes)
        end
        deserializer.attributes = deserializer.attributes.permit(strong_resource)

        deserializer.relationships.each_pair do |name, relationship_payload|
          if strong_resource[:relationships].has_key?(name)
            [relationship_payload].flatten.each do |rp|
              apply_strong_param(rp, strong_resource[:relationships][name])
            end
          else
            deserializer.relationships.delete(name)
          end
        end
      end

      # TODO: refactor
      def apply_strong_param(relationship_payload, permitted)
        if relationship_payload[:meta][:method] == :disassociate
          raise 'not allowed disass' unless permitted[:_disassociate]
        end

        if relationship_payload[:meta][:method] == :destroy
          raise 'not allowed destroy' unless permitted[:_destroy]
        end

        unless relationship_payload[:attributes].respond_to?(:permit)
          relationship_payload[:attributes] = ActionController::Parameters.new(relationship_payload[:attributes])
        end

        relationship_payload[:attributes] = relationship_payload[:attributes].permit(permitted)
        relationship_payload[:relationships].each_pair do |name, rp|
          [rp].flatten.each do |_rp|
            apply_strong_param(_rp, permitted[:relationships][name])
          end
        end
      end

      def strong_resource
        resources = self.class._strong_resources
        raise RuntimeError, "You need to define the `strong_resource` for #{class.name}" if resources.nil?
        resource = resources[action_name.to_sym]
        raise RuntimeError, "Missing `strong_resource` parameters for #{class.name}##{action_name}" if resource.nil?
        _params = params
        resource.permits(self)
      end

      module ClassMethods
        def strong_resource(name, opts = {}, &blk)
          resource = StrongResource.from(name, opts, &blk)

          resources = { create: resource, update: resource }
          resource.customized_actions.each_pair do |action_name, prc|
            resource = StrongResource.from(name, opts, &blk)
            resource.instance_eval(&prc)
            resources[action_name] = resource
          end

          self._strong_resources = resources
        end
      end
    end
  end
end

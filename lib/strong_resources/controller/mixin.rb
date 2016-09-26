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

      def strong_resource
        resource = self.class._strong_resources[action_name.to_sym]
        _params = params
        _params = _params.require(resource.require) if resource.require
        _params.permit(resource.permits(self))
      end

      def update_action?
        action_name == 'update'
      end

      module ClassMethods
        def strong_resource(name, opts = {}, &blk)
          blk ||= Proc.new {}
          opts[:require] ||= name unless opts[:require] == false
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

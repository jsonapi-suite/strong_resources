module StrongResources
  module Controller
    module Mixin
      class JSONParams
        attr_reader :params
        def initialize(controller)
          params_method = if controller.respond_to?(:raw_params)
                            :raw_params
                          else
                            :params
                          end

          @params = controller.send(params_method)
        end

        def type
          params.try(:[], :data).try(:[], :type).try(:to_sym).try(:to_s)
        end
      end

      extend ActiveSupport::Concern

      included do
        class_attribute :_strong_resources
        self._strong_resources = {}

        def self.inherited(klass)
          super
          klass._strong_resources = self._strong_resources.deep_dup
        end
      end

      def strong_resource
        _params_type = JSONParams.new(self).type
        unless resource_for_type = self.class._strong_resources[_params_type]
          raise ::StrongResources::UnregisteredResource.new(_params_type)
        end

        resource = resource_for_type[action_name.to_sym]

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

          self._strong_resources[resource.jsonapi_type] = resources
        end
      end
    end
  end
end

module StrongResources
  module Controller
    module Mixin
      extend ActiveSupport::Concern
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
          params.try(:[], :data).try(:[], :type).try(:to_sym)
        end
      end

      included do
        class_attribute :_strong_resources, instance_writer: false
        self._strong_resources = {}
      end

      def strong_resource

        _params_type = JSONParams.new(self).type
        resource = self.class._strong_resources[_params_type][action_name.to_sym]
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
          type = opts[:type] || name

          resources = { create: resource, update: resource }
          resource.customized_actions.each_pair do |action_name, prc|
            resource = StrongResource.from(name, opts, &blk)
            resource.instance_eval(&prc)
            resources[action_name] = resource
          end

          self._strong_resources[type.to_sym] = resources
        end
      end
    end
  end
end

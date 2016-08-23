module StrongResources
  class StrongResource
    attr_accessor :attributes, :relations, :require, :relation_type,
      :only,
      :except,
      :delete,
      :destroy
    attr_reader :name, :customized_actions, :jsonapi_type

    def self.from(name, opts = {}, &blk)
      config   = StrongResources.config.strong_resources[name]
      resource = new(name)
      resource.require = opts[:require]
      resource.instance_eval(&config[:base])
      resource.instance_eval(&blk) if blk
      resource
    end

    def initialize(name)
      @name = name
      @jsonapi_type = name.to_s.pluralize
      @customized_actions = {}
      self.attributes = {}
      self.relations = {}
    end

    def jsonapi_type(type = nil)
      if type
        @jsonapi_type = type
      else
        @jsonapi_type
      end
    end

    def delete?
      !!@delete
    end

    def destroy?
      !!@destroy
    end

    def attribute(name, type, opts = {})
      self.attributes[name] = { type: type, if: opts[:if] }
    end

    def remove_attribute(name)
      self.attributes.delete(name)
    end

    def on(action_name, &blk)
      self.customized_actions[action_name] = blk
    end

    def has_many?
      relation_type == :has_many
    end

    def has_many(name,
                 resource: nil,
                 only: nil,
                 except: nil,
                 delete: false,
                 destroy: false,
                 &blk)
      resource_name = resource || name.to_s.singularize.to_sym
      related_resource = self.class.from(resource_name)
      related_resource.instance_eval(&blk) if block_given?
      related_resource.relation_type = :has_many
      add_relation(name, related_resource, only, except, delete, destroy)
    end

    def belongs_to(name,
                   resource: nil,
                   only: nil,
                   except: nil,
                   delete: false,
                   destroy: false,
                   &blk)
      resource_name = resource || name
      related_resource = self.class.from(resource_name, &blk)
      add_relation(name, related_resource, only, except, delete, destroy)
    end

    def has_one(*args, &blk)
      belongs_to(*args, &blk)
    end

    def permits(controller)
      base_permits(self, controller).tap do |permits|
        self.relations.each_pair do |relation_name, opts|
          related_resource = opts[:resource]
          related = related_permits(related_resource, controller)

          permits.merge!(:"#{relation_name}_attributes" => related)
        end
      end
    end

    private

    def base_permits(resource, controller)
      permits = {}
      resource.attributes.each_pair do |name, opts|
        next if (opts[:if] and opts[:if].call(controller) == false)
        permits.merge!(name => StrongResources.type_for_param(opts[:type]))
      end

      permits = permits.slice(*resource.only) if resource.only
      permits = permits.except(*resource.except) if resource.except
      permits
    end

    def related_permits(related_resource, controller)
      related_resource.permits(controller).tap do |permits|
        permits.merge!(id: StrongResources.type_for_param(:id))

        if controller.update_action?
          merge_delete_destroy(related_resource, permits)
        end
      end
    end

    def merge_delete_destroy(related_resource, permits)
      if related_resource.delete?
        permits.merge!(_delete: StrongResources.type_for_param(:boolean))
      end

      if related_resource.destroy?
        permits.merge!(_destroy: StrongResources.type_for_param(:boolean))
      end
    end

    def add_relation(name, resource, only, except, delete, destroy)
      resource.only = only
      resource.except = except
      resource.delete = delete
      resource.destroy = destroy

      self.relations[name] = {
        resource: resource
      }
    end
  end
end

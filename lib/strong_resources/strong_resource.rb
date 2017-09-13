module StrongResources
  class StrongResource
    attr_accessor :attributes,
      :relations,
      :relation_type,
      :only,
      :except,
      :disassociate,
      :destroy
    attr_reader :name, :customized_actions, :jsonapi_type

    def self.from(name, opts = {}, &blk)
      config   = StrongResources.find(name)
      resource = new(name)
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

    def disassociate?
      !!@disassociate
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

    def remove_relationship(name)
      self.relations.delete(name)
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
                 disassociate: false,
                 destroy: false,
                 &blk)
      resource_name = resource || name.to_s.singularize.to_sym
      related_resource = self.class.from(resource_name)
      related_resource.instance_eval(&blk) if block_given?
      related_resource.relation_type = :has_many
      add_relation(name, related_resource, only, except, disassociate, destroy)
    end

    def belongs_to(name,
                   resource: nil,
                   only: nil,
                   except: nil,
                   disassociate: false,
                   destroy: false,
                   &blk)
      resource_name = resource || name
      related_resource = self.class.from(resource_name, &blk)
      add_relation(name, related_resource, only, except, disassociate, destroy)
    end

    def has_one(*args, &blk)
      belongs_to(*args, &blk)
    end

    def permits(controller)
      base_permits(self, controller).tap do |permits|
        self.relations.each_pair do |relation_name, opts|
          related_resource = opts[:resource]
          related = related_permits(related_resource, controller)

          permits[:relationships] ||= {}
          permits[:relationships][relation_name] = related
          permits
        end
      end
    end

    private

    def base_permits(resource, controller)
      permits = {}
      permits.merge!(id: StrongResources.type_for_param(:id))
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
        merge_disassociate_destroy(related_resource, permits)
      end
    end

    def merge_disassociate_destroy(related_resource, permits)
      if related_resource.disassociate?
        permits.merge!(_disassociate: true)
      end

      if related_resource.destroy?
        permits.merge!(_destroy: true)
      end
    end

    def add_relation(name, resource, only, except, disassociate, destroy)
      resource.only = only
      resource.except = except
      resource.disassociate = disassociate
      resource.destroy = destroy

      self.relations[name] = {
        resource: resource
      }
    end
  end
end

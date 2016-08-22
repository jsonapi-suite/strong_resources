module StrongResources
  class Configuration
    attr_accessor :strong_params, :strong_resources

    def initialize
      self.strong_resources = {}
      self.strong_params = {}
      define_default_params
    end

    def strong_param(name, swagger:, type:)
      self.strong_params[name] = { swagger: swagger, type: type }
    end

    def strong_resource(name, &blk)
      resource = { name: name, base: blk }
      self.strong_resources[name] = resource
    end

    private

    def define_default_params
      strong_param :id, swagger: :string, type: ActionController::Parameters.string
      strong_param :string, swagger: :string, type: ActionController::Parameters.string
      strong_param :integer, swagger: :integer, type: ActionController::Parameters.integer
      strong_param :boolean, swagger: :boolean, type: ActionController::Parameters.boolean
    end
  end
end

module StrongResources
  class StrongResourceGenerator < ::Rails::Generators::NamedBase
    argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

    desc "Generate strong_resource payload"
    def generate_strong_resource
      code = "  strong_resource :#{singular_table_name} do\n"
      attributes.each do |a|
        code << "    attribute :#{a.name}, :#{transform_type(a.type)}\n"
      end
      code << "  end\n"

      inject_into_file 'config/initializers/strong_resources.rb', after: "StrongResources.configure do\n" do
        code
      end
    end

    private

    def transform_type(type)
      case type
      when :text
        :string
      when :float, :decimal
        :number
      else
        type
      end
    end
  end
end

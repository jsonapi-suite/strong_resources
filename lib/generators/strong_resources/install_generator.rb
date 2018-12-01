module StrongResources
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    class_option :comments,
                 type: :boolean,
                 default: false,
                 aliases: %w[-c],
                 desc: 'Generate documentation comments'

    desc "Create strong_resources initializer"
    def create_initializer
      template 'strong_resources.rb', 'config/initializers/strong_resources.rb'
    end
  end
end

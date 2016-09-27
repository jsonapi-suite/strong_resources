$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'rails'
require 'action_controller'

class FakeApplication < Rails::Application; end

Rails.application = FakeApplication
Rails.configuration.action_controller = ActiveSupport::OrderedOptions.new
Rails.configuration.secret_key_base = 'secret_key_base'

module ActionController
  SharedTestRoutes = ActionDispatch::Routing::RouteSet.new
  SharedTestRoutes.draw do
    resources :people
  end

  class Base
    include ActionController::Testing
    include SharedTestRoutes.url_helpers
  end

  class ActionController::TestCase
    setup do
      @routes = SharedTestRoutes
    end
  end
end

require 'strong_resources'
require 'rspec/rails'
require 'pry'
require 'pry-byebug'

StrongResources.configure do
  strong_param :pet_kind,
    swagger: :string,
    type: ActionController::Parameters.enum('Dog', 'Cat')

  strong_resource :person do
    attribute :name, :string
  end

  strong_resource :pet do
    attribute :name, :string
    attribute :kind, :pet_kind
  end

  strong_resource :company do
    attribute :title, :string
    attribute :revenue, :integer
  end

  strong_resource :parent_company do
    attribute :title, :string
  end

  strong_resource :unicorn do
    attribute :title, :string
  end

  strong_resource :state do
    attribute :acronym, :string
  end
end

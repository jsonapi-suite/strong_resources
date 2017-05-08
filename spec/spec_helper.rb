$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'jsonapi_compliable'
require 'action_pack'
require 'action_controller'

module ActionController
  SharedTestRoutes = ActionDispatch::Routing::RouteSet.new
  SharedTestRoutes.draw do
    resources :people
  end

  class Base
    include ActionController::Testing
    include SharedTestRoutes.url_helpers
  end

  #class ActionController::TestCase
    #setup do
      #@routes = SharedTestRoutes
    #end
  #end
end

require 'strong_resources'
require 'rspec'
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

  strong_resource :state do
    attribute :acronym, :string
  end
end

class PeopleController < ActionController::Base
  include StrongResources::Controller::Mixin
  include JsonapiCompliable::Base

  strong_resource :person do
    has_many :pets, only: [:kind], destroy: true
    has_many :siblings, resource: :person, disassociate: true

    belongs_to :company, except: [:revenue] do
      belongs_to :state
    end
  end

  def create
    render json: strong_resource
  end
end

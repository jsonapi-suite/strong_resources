require 'spec_helper'

describe 'strong_resources' do
  let(:controller) do
    controller_klass.new.tap do | controller |
      controller.params = ActionController::Parameters.new(params)
      allow(controller).to receive(:action_name) { :create }
    end
  end

  context 'when single resource defined'  do
    let(:controller_klass) do
      Class.new(ActionController::Base) do
        include StrongResources::Controller::Mixin

        strong_resource :person do
          has_many :pets, only: [:kind], destroy: true
          has_many :siblings, resource: :person, delete: true

          belongs_to :company, except: [:revenue] do
            belongs_to :state
          end
        end

        def create
          render json: strong_resource
        end
      end
    end

    let(:params) do
      { person: { name: 'John' }, data: { type: 'people' }  }
    end

    describe 'basic POST', type: :request do
      context 'with bad param name' do
        before do
          params[:person][:foo] = 'bar'
        end

        it 'only allows correct param names' do
          expect(controller.strong_resource.to_h).to eq('name' => 'John')
        end
      end

      context 'with bad param value' do
        before do
          params[:person][:name] = 1
        end

        it 'disallows incorrect values' do
          expect {
            expect(controller.strong_resource.to_h)
          }.to raise_error(StrongerParameters::InvalidParameter)
        end
      end

      context 'with relation' do
        before do
          params[:person][:pets_attributes] = [
            { kind: 'Dog' }
          ]
        end

        it 'allows whitelisted relations' do
          expect(controller.strong_resource.to_h)
            .to eq('name' => 'John', 'pets_attributes' => [{ 'kind' => 'Dog' }])
        end

        context 'when an update action' do
          context 'when :destroy is true' do
            before do
              params[:person][:pets_attributes][0][:_destroy] = true
              params[:person][:pets_attributes][0][:_delete] = true
              allow(controller).to receive(:update_action?) { true }
            end

            it 'adds _destroy param' do
              pets_attrs = controller.strong_resource.to_h['pets_attributes'][0]
              expect(pets_attrs['_destroy']).to eq(true)
              expect(pets_attrs).to_not have_key('_delete')
            end
          end

          context 'when :delete is true' do
            before do
              params[:person].delete(:pets_attributes)
              params[:person][:siblings_attributes] = [{ id: '1', _delete: true, _destroy: true }]
              allow(controller).to receive(:update_action?) { true }
            end

            it 'adds _delete param' do
              siblings_attrs = controller.strong_resource.to_h['siblings_attributes'][0]
              expect(siblings_attrs['_delete']).to eq(true)
              expect(siblings_attrs).to_not have_key('_destroy')
            end
          end
        end

        context 'when passed wrong type' do
          before do
            params[:person][:pets_attributes][0][:kind] = 'Ferret'
          end

          it 'raises stronger_parameters error' do
            expect {
              controller.strong_resource.to_h
            }.to raise_error(StrongerParameters::InvalidParameter)
          end
        end

        context 'when limited by :only' do
          before do
            params[:person][:pets_attributes][0][:name] = 'Lassie'
          end

          it 'drops attributes unless whitelisted by :only' do
            expect(controller.strong_resource.to_h)
              .to eq('name' => 'John', 'pets_attributes' => [{ 'kind' => 'Dog' }])
          end
        end

        context 'when limited by :except' do
          before do
            params[:person].delete(:pets_attributes)
            params[:person][:company_attributes] = { title: 'walmart', revenue: 10 }
          end

          it 'drops attributes blacklisted by :except' do
            expect(controller.strong_resource.to_h)
              .to eq('name' => 'John', 'company_attributes' => { 'title' => 'walmart' })
          end
        end

        context 'that goes by alternate name' do
          before do
            params[:person].delete(:pets_attributes)
            params[:person][:siblings_attributes] = [
              { name: 'Jane' }
            ]
          end

          it 'allows name and matches with correct resource' do
            expect(controller.strong_resource.to_h)
              .to eq('name' => 'John', 'siblings_attributes' => [{ 'name' => 'Jane' }])
          end
        end

        context 'that is nested' do
          before do
            params[:person].delete(:pets_attributes)
            params[:person][:company_attributes] = {
              title: 'walmart',
              state_attributes: {
                acronym: 'ny'
              }
            }
          end

          it 'allows nesting relations' do
            expect(controller.strong_resource.to_h)
              .to eq('name' => 'John', 'company_attributes' => {
                'title' => 'walmart',
                'state_attributes' => {
                  'acronym' => 'ny'
                }
              })
          end
        end
      end
    end
  end

  context 'with multiple strong_resources' do
     let(:company_base_klass) do
      Class.new(ActionController::Base) do
        include StrongResources::Controller::Mixin

        strong_resource :company do
          belongs_to :state
          belongs_to :parent_company
        end

        strong_resource :parent_company do
          belongs_to :state
        end

        def create
          render json: strong_resource
        end
       end
     end


    context "on base class" do
      let(:controller_klass) { company_base_klass }

      context "request payload strong_resource == 'parent_company'" do
        let(:params) do
          { parent_company: { title: 'walmart' }, data: { type: 'parent_companies' } }
        end

        it 'core params are allowed' do
          params[:parent_company][:foo] = 'bar'
          expect(controller.strong_resource.to_h).to eq('title' => 'walmart')
        end

        it 'relation params are allowed' do
          params[:parent_company][:parent_company_attributes] =  {
            title: 'walmart'
          }
          params[:parent_company][:state_attributes] =  {
            acronym: 'ar'
          }
          expect(controller.strong_resource.to_h).to eq('title' => 'walmart', 'state_attributes' => { 'acronym' => 'ar' })
        end
      end

      context "request payload strong_resource == 'company'" do
        let(:params) do
          { company: { title: 'Jet.com' }, data: { type: 'companies' } }
        end

        it 'core params are allowed' do
          params[:company][:foo] = 'bar'
          expect(controller.strong_resource.to_h).to eq('title' => 'Jet.com')
        end

        it 'relation params are allowed' do
          params[:company][:parent_company_attributes] =  {
            title: 'walmart'
          }
          params[:company][:state_attributes] =  {
            acronym: 'ar'
          }

          expect(controller.strong_resource.to_h)
            .to eq('title' => 'Jet.com', 'parent_company_attributes' => {
              'title' => 'walmart',
            },'state_attributes' => {
                'acronym' => 'ar'
            })
        end
      end

        context "jsontype of subclasses" do
          let(:params) do
            { unicorn: { title: 'Jet.com' }, data: { type: 'unicorns' } }
          end

          it 'should raise exception' do
            expect {
              controller.strong_resource.to_h
            }.to raise_error StrongResources::UnregisteredResource
          end
        end
    end

    context "when subclassed" do
      let(:controller_klass) do
         Class.new(company_base_klass) do
          strong_resource :unicorn
         end
      end

      context "request strong_resource defined on parent" do
        let(:params) do
          { parent_company: { title: 'walmart' }, data: { type: 'parent_companies' } }
        end

        it 'allows core params' do
          params[:parent_company][:foo] = 'bar'
          expect(controller.strong_resource.to_h).to eq('title' => 'walmart')
        end

        it 'allows relation params' do
          params[:parent_company][:parent_company_attributes] =  {
            title: 'walmart'
          }
          params[:parent_company][:state_attributes] =  {
            acronym: 'ar'
          }
          expect(controller.strong_resource.to_h).to eq('title' => 'walmart', 'state_attributes' => { 'acronym' => 'ar' })
        end
      end

      context "request strong_resource defined on subclass" do
        let(:params) do
          { unicorn: { title: 'Jet.com' }, data: { type: 'unicorns' } }
        end

        it 'allows core params' do
          expect(controller.strong_resource.to_h).to eq('title' => 'Jet.com')
        end
      end
    end
  end
end

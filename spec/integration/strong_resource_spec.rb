require 'spec_helper'

describe 'strong_resources' do
  let(:controller) do
    controller = PeopleController.new
    controller.params = ActionController::Parameters.new(params)
    allow(controller).to receive(:action_name) { :create }
    controller
  end

  let(:params) do
    { person: { name: 'John' },  data: { type: 'person' }  }
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

describe "strong_resources" do
  context "with multiple definitions" do
    let(:controller) do
      controller = CompaniesController.new
      controller.params = ActionController::Parameters.new(params)
      allow(controller).to receive(:action_name) { :create }
      controller
    end


    context "request payload strong_resource == 'parent_company'" do
      let(:params) do
        { parent_company: { title: 'John' }, data: { type: 'parent_company' } }
      end

      it 'core params are allowed' do
        params[:parent_company][:foo] = 'bar'
        expect(controller.strong_resource.to_h).to eq('title' => 'John')
      end

      it 'relation params are allowed' do
        params[:parent_company][:parent_company_attributes] =  {
          title: 'Parent Company'
        }
        params[:parent_company][:state_attributes] =  {
          acronym: 'VA'
        }
        expect(controller.strong_resource.to_h).to eq('title' => 'John', 'state_attributes' => { 'acronym' => 'VA' })
      end
    end

    context "request payload strong_resource == 'company'" do
      let(:params) do
        { company: { title: 'John' }, data: { type: 'company' } }
      end

      it 'core params are allowed' do
        params[:company][:foo] = 'bar'
        expect(controller.strong_resource.to_h).to eq('title' => 'John')
      end

      it 'relation params are allowed' do
        params[:company][:parent_company_attributes] =  {
          title: 'Parent Company'
        }
        params[:company][:state_attributes] =  {
          acronym: 'VA'
        }
        expect(controller.strong_resource.to_h).to eq('title' => 'John', 
                                                      'state_attributes' => { 'acronym' => 'VA' },
                                                      'parent_company_attributes' => { 'title' => 'Parent Company' })
      end
    end

    context "request payload strong_resource == 'unicorn'" do
      let(:params) do
        { unicorn: { title: 'John' }, data: { type: 'unicorn' } }
      end

      it 'core params are allowed' do
        expect(controller.strong_resource.to_h).to eq('title' => 'John')
      end
    end
  end
end

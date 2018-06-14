require 'spec_helper'

describe 'strong_resources' do
  let(:make_controller) { -> (klass) {
      controller = klass.new
      controller.params = ActionController::Parameters.new(params)
      allow(controller).to receive(:action_name) { :create }
      allow(controller).to receive(:params) { ActionController::Parameters.new(params) }
      allow(controller).to receive(:request) do
        double(env: { 'METHOD' => 'POST' })
      end
      controller
  }}
  
  let(:controller) { make_controller.call(PeopleController) }
  let(:colors_controller) { make_controller.call(ColorsController) }

  let(:params) do
    {
      data: {
        id: '1',
        attributes: { name: 'John' }
      }
    }
  end

  describe 'basic POST', type: :request do
    it 'whitelists relevant params' do
      expect(!!controller.deserialized_params.attributes.permitted?)
        .to be(false)

      controller.apply_strong_params

      expect(!!controller.deserialized_params.attributes.permitted?)
        .to be(true)
    end

    context 'when unknown type is referenced' do
      def with_type(val)
        begin
          action = controller.class._strong_resources[:create]
          name = action.attributes[:name]
          original = name[:type]
          name[:type] = val
          yield
        ensure
          name[:type] = original
        end
      end

      it 'raises helpful error' do
        with_type(:foo) do
          expect {
            controller.apply_strong_params
          }.to raise_error(StrongResources::UnregisteredType)
        end
      end
    end

    context 'when attribute is removed for the given action' do
      before do
        allow(controller).to receive(:action_name) { :update }
        allow(controller).to receive(:request) do
          double(env: { 'METHOD' => 'PUT' })
        end
      end

      it 'does not whitelist the attribute' do
        expect(controller.deserialized_params.attributes.keys)
          .to match_array(%w(name id))
        controller.apply_strong_params
        expect(controller.deserialized_params.attributes.keys)
          .to match_array(%w(id))
      end
    end

    context 'when relationship is removed for the given action' do
      before do
        allow(controller).to receive(:action_name) { :update }
        allow(controller).to receive(:request) do
          double(env: { 'METHOD' => 'PUT' })
        end

        params[:data][:relationships] = {
          company: {
            data: {
              id: '1', type: 'companies'
            }
          }
        }
      end

      it 'does not whitelist the relationship' do
        expect(controller.deserialized_params.relationships.keys)
          .to match_array([:company])
        controller.apply_strong_params
        expect(controller.deserialized_params.relationships.keys)
          .to match_array([])
      end
    end

    context 'with bad param name' do
      before do
        params[:data][:attributes][:foo] = 'bar'
      end

      it 'only allows correct param names' do
        expect(controller.deserialized_params.attributes.keys)
          .to match_array(%w(name foo id))
        controller.apply_strong_params
        expect(controller.deserialized_params.attributes.keys)
          .to match_array(%w(name id))
      end
    end

    context 'with bad param value' do
      before do
        params[:data][:attributes][:name] = 1
      end

      it 'disallows incorrect values' do
        expect {
          controller.apply_strong_params
        }.to raise_error(StrongerParameters::InvalidParameter)
      end
    end

    context 'with relation' do
      before do
        params[:data][:relationships] = {
          pets: {
            data: [
              { id: '1', type: 'pets' }
            ]
          },
          foo: {
            data: {
              type: 'foos', id: '1'
            }
          }
        }

        params[:included] = [
          {
            type: 'pets',
            id: '1',
            attributes: { kind: 'Dog' }
          },
          {
            type: 'foos',
            id: '1',
            attributes: { scrub: 'me' }
          }
        ]
      end

      it 'allows whitelisted relations' do
        controller.apply_strong_params
        relationships = controller.deserialized_params.relationships
        expect(relationships.keys).to match_array([:pets])
        expect(relationships).to_not have_key(:foo)
        expect(relationships[:pets][0][:attributes].to_h)
          .to eq({ 'id' => '1', 'kind' => 'Dog' })
      end

      context 'when no relationships are defined on the strong resource' do
        let(:no_relationship_controller) { colors_controller }
        
        it 'does not error, matching normal behavior for extra params' do
          expect {
            no_relationship_controller.apply_strong_params
          }.to_not raise_error
        end
      end

      context 'when passed wrong type' do
        before do
          params[:included][0][:attributes][:kind] = 'Ferret'
        end

        it 'raises stronger_parameters error' do
          expect {
            controller.apply_strong_params
          }.to raise_error(StrongerParameters::InvalidParameter)
        end
      end

      context 'when limited by :only' do
        before do
          params[:data][:attributes][:name] = 'Lassie'
        end

        it 'drops attributes unless whitelisted by :only' do
          controller.apply_strong_params
          pet = controller.deserialized_params.relationships[:pets][0]
          expect(pet[:attributes]).to_not have_key(:name)
          expect(pet[:attributes]).to_not have_key('name')
        end
      end

      context 'when limited by :except' do
        before do
          params[:data][:relationships][:company] = {
            data: { id: '1', type: 'companies' }
          }
          params[:included] << {
            type: 'companies', id: '1', attributes: { title: 'walmart', revenue: 10 }
          }
        end

        it 'drops attributes blacklisted by :except' do
          controller.apply_strong_params
          company = controller.deserialized_params.relationships[:company]
          expect(company[:attributes].to_h).to eq({
            'id' => '1',
            'title' => 'walmart'
          })
        end
      end

      context 'that goes by alternate name' do
        before do
          params[:data][:relationships][:siblings] = {
            data: [
              { id: '1', type: 'people' }
            ]
          }

          params[:included] << {
            id: '1',
            type: 'people',
            attributes: { name: 'Jane' }
          }
        end

        it 'allows name and matches with correct resource' do
          controller.apply_strong_params
          sibling = controller.deserialized_params.relationships[:siblings][0]
          expect(sibling[:attributes].to_h).to eq({ 'id' => '1', 'name' => 'Jane' })
        end
      end

      context 'that is nested' do
        before do
          params[:data][:relationships][:company] = {
            data: { id: '1', type: 'companies' }
          }
          params[:included] << {
            id: '1',
            type: 'companies',
            attributes: { title: 'walmart' },
            relationships: {
              state: {
                data: {
                  id: '1', type: 'states'
                }
              }
            }
          }
          params[:included] << {
            type: 'states',
            id: '1',
            attributes: { acronym: 'ny' }
          }
        end

        it 'allows nesting relations' do
          controller.apply_strong_params
          company = controller.deserialized_params.relationships[:company]
          state = company[:relationships][:state]
          expect(state[:attributes].to_h).to eq({
            'id' => '1',
            'acronym' => 'ny'
          })
        end
      end
    end
  end
end

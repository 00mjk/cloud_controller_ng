require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Schema do
    describe '#to_json' do
      let(:schema) { Schema.new(raw_schema) }
      let(:raw_schema) {
        {
          '$schema' => 'http://json-schema.org/draft-04/schema#',
          'type' => 'object',
          :properties => { 'foo': { 'type': 'string' } },
          :required => ['foo']
        }
      }

      it 'converts a hash into json' do
        expect(schema.to_json).to eq '{"$schema":"http://json-schema.org/draft-04/schema#",'\
          '"type":"object",'\
          '"properties":{"foo":{"type":"string"}},'\
          '"required":["foo"]}'
      end
    end

    describe 'schema validations' do
      let(:draft_schema) { "http://json-schema.org/#{version}/schema#" }
      let(:raw_schema) { { '$schema' => draft_schema, 'type' => 'object' } }
      let(:schema) { Schema.new(raw_schema) }

      context 'JSON Schema draft04 validations' do
        let(:version) { 'draft-04' }

        context 'when the schema has an internal reference' do
          let(:raw_schema) {
            {
              'type' => 'object',
              'properties': {
                'foo': { 'type': 'integer' },
                'bar': { '$ref': '#/properties/foo' }
              }
            }
          }

          it 'should be valid' do
            expect(schema.validate).to be true
            expect(schema.errors.full_messages.length).to be 0
          end
        end

        context 'when the schema has multiple valid constraints ' do
          let(:raw_schema) {
            {
              '$schema' => draft_schema,
              'type' => 'object',
              :properties => { 'foo': { 'type': 'string' } },
              :required => ['foo']
            }
          }

          it 'should be valid' do
            expect(schema.validate).to be true
            expect(schema.errors.full_messages.length).to be 0
          end
        end

        context 'errors' do
          context 'properties' do
            context 'when boolean' do
              let(:raw_schema) { { 'type' => 'object', 'properties': true } }

              it 'should not be valid' do
                expect(schema.validate).to be false
                expect(schema.errors.full_messages.length).to eq 1
                expect(schema.errors.full_messages.first).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
                  "The property '#/properties' of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#"
              end
              context 'when there are multiple errors' do
                let(:raw_schema) { { 'type' => 'object', 'properties': true, 'anyOf': true } }

                it 'should have more than one error message' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 2
                  expect(schema.errors.full_messages.first).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
                    'The property \'#/properties\' of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#'
                  expect(schema.errors.full_messages.last).to eq 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
                    'The property \'#/anyOf\' of type boolean did not match the following type: array in schema http://json-schema.org/draft-04/schema#'
                end
              end

              context 'when the schema has an external schema' do
                let(:raw_schema) { { 'type' => 'object', '$schema': 'http://example.com/schema' } }

                it 'should not be valid' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to eq 'Custom meta schemas are not supported.'
                end
              end

              context 'references' do
                context 'when the schema has an external uri reference' do
                  let(:raw_schema) { { 'type' => 'object', '$ref': 'http://example.com/ref' } }

                  it 'should not be valid' do
                    expect(schema.validate).to be false
                    expect(schema.errors.full_messages.length).to eq 1
                    expect(schema.errors.full_messages.first).to match 'No external references are allowed.+http://example.com/ref'
                  end
                end

                context 'when the schema has an external file reference' do
                  let(:raw_schema) { { 'type' => 'object', '$ref': 'path/to/schema.json' } }

                  it 'should not be valid' do
                    expect(schema.validate).to be false
                    expect(schema.errors.full_messages.length).to eq 1
                    expect(schema.errors.full_messages.first).to match 'No external references are allowed.+path/to/schema.json'
                  end
                end
              end
            end
          end

          context 'when the schema does not have a type field' do
            let(:raw_schema) { { '$schema': 'http://json-schema.org/draft-04/schema#' } }

            it 'should not be valid' do
              expect(schema.validate).to be false
              expect(schema.errors.full_messages.length).to eq 1
              expect(schema.errors.full_messages.first).to eq 'must have field "type", with value "object"'
            end
          end

          context 'when the schema has an unknown parse error' do
            before do
              allow(JSON::Validator).to receive(:validate!) { raise 'some unknown error' }
            end

            it 'should not be valid' do
              expect(schema.validate).to be false
              expect(schema.errors.full_messages.length).to eq 1
              expect(schema.errors.full_messages.first).to eq 'some unknown error'
            end
          end

          describe 'validation ordering' do
            context 'when an invalid schema fails multiple validations' do
              context 'schema size and schema type' do
                let(:raw_schema) { create_schema_of_size(64 * 1024) }
                before { raw_schema['type'] = 'notobject' }

                it 'returns one error' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
                end
              end

              context 'schema size and external reference' do
                let(:raw_schema) { create_schema_of_size(64 * 1024) }
                before { raw_schema['$ref'] = 'http://example.com/ref' }

                it 'returns one error' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
                end
              end

              context 'schema size and does not conform to Json Schema Draft 4' do
                let(:raw_schema) { create_schema_of_size(64 * 1024) }
                before { raw_schema['properties'] = true }

                it 'returns one error' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
                end
              end

              context 'schema type and does not conform to JSON Schema Draft 4' do
                let(:raw_schema) { { 'type' => 'notobject', 'properties' => true } }

                it 'returns one error' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to match 'must have field "type", with value "object"'
                end
              end

              context 'does not conform to JSON Schema Draft 4 and external references' do
                let(:raw_schema) { { 'type' => 'object', 'properties' => true, '$ref' => 'http://example.com/ref' } }

                it 'returns one error' do
                  expect(schema.validate).to be false
                  expect(schema.errors.full_messages.length).to eq 1
                  expect(schema.errors.full_messages.first).to match 'Must conform to JSON Schema Draft 04 (experimental support for later versions): ' \
                    'The property \'#/properties\' of type boolean did not match the following type: ' \
                    'object in schema http://json-schema.org/draft-04/schema#'
                end
              end
            end
          end

          describe 'schema sizes' do
            context 'that are valid' do
              {
                'well below the limit': 1,
                'just below the limit': 63,
                'on the limit': 64,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

                  it 'should be valid' do
                    expect(schema.validate).to be true
                    expect(schema.errors.full_messages.length).to eq 0
                  end
                end
              end
            end

            context 'that are invalid' do
              {
                'just above the limit': 65,
                'well above the limit': 10 * 1024,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  let(:raw_schema) { create_schema_of_size(size_in_kb * 1024) }

                  it 'returns one error' do
                    expect(schema.validate).to be false
                    expect(schema.errors.full_messages.length).to eq 1
                    expect(schema.errors.full_messages.first).to match 'Must not be larger than 64KB'
                  end
                end
              end
            end
          end

          def create_schema_of_size(bytes)
            surrounding_bytes = 26
            {
              'type' => 'object',
              'foo' => 'x' * (bytes - surrounding_bytes)
            }
          end
        end
      end

      context 'JSON Schema draft06 validations' do
        let(:version) { 'draft-06' }

        context 'when the schema has multiple valid constraints ' do
          let(:raw_schema) {
            {
              '$schema' => draft_schema,
              'type' => 'object',
              :properties => { 'foo': { 'type': 'string' } },
              :required => ['foo']
            }
          }

          it 'should be valid' do
            expect(schema.validate).to be true
            expect(schema.errors.full_messages.length).to be 0
          end
        end
      end

      context 'when neither draft6 nor draft4 schema has been specified' do
        let(:version) { 'some-random-schema' }

        it 'should return a helpful error' do
          expect(schema.validate).to be false
          expect(schema.errors.full_messages.length).to eq 1
          expect(schema.errors.full_messages.first).to match 'Custom meta schemas are not supported'
        end
      end
    end
  end
end

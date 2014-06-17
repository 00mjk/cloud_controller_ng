require "spec_helper"
require "stringio"

module VCAP::CloudController
  class TestModelsController < RestController::ModelController
    define_attributes do
      attribute :required_attr, TrueClass
      attribute :unique_value, String
      to_many :test_model_many_to_ones
      to_many :test_model_many_to_manies
    end
    define_messages
    define_routes

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details("TestModelValidation", attributes["unique_value"])
    end
  end

  class TestModelManyToOnesController < RestController::ModelController
    define_attributes do
      to_one :test_model
    end

    define_messages
    define_routes
  end

  class TestModelManyToManiesController < RestController::ModelController
    define_attributes do
    end

    define_messages
    define_routes
  end

  describe RestController::ModelController do
    let(:user) { User.make(active: true) }

    describe "common model controller behavior" do
      before do
        get "/v2/test_models", "", headers
      end

      context "for an existing user" do
        let(:headers) do
          headers_for(user)
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for a user not yet in cloud controller" do
        let(:headers) do
          headers_for(Machinist.with_save_nerfed { VCAP::CloudController::User.make })
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for a deleted user" do
        let(:headers) do
          headers = headers_for(user)
          user.delete
          headers
        end

        it "returns 200 by recreating the user" do
          last_response.status.should == 200
        end
      end

      context "for an admin" do
        let(:headers) do
          admin_headers
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for no user" do
        let(:headers) do
          headers_for(nil)
        end

        it "should return 401" do
          last_response.status.should == 401
        end
      end
    end

    describe "#create" do
      it "calls the hooks in the right order" do
        calls = []

        TestModelsController.any_instance.should_receive(:before_create).with(no_args) do
          calls << :before_create
        end
        TestModel.should_receive(:create_from_hash) {
          calls << :create_from_hash
          TestModel.make
        }
        TestModelsController.any_instance.should_receive(:after_create).with(instance_of(TestModel)) do
          calls << :after_create
        end

        post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), admin_headers

        expect(calls).to eq([:before_create, :create_from_hash, :after_create])
      end

      context "when the user's token is missing the required scope" do
        it 'responds with a 403 Insufficient Scope' do
          post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user, scopes: ['bogus.scope'])
          expect(decoded_response["code"]).to eq(10007)
          expect(decoded_response["description"]).to match(/lacks the necessary scopes/)
        end
      end

      it "does not persist the model when validate access fails" do
        expect {
          post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
        }.to_not change { TestModel.count }

        expect(decoded_response["code"]).to eq(10003)
        expect(decoded_response["description"]).to match(/not authorized/)
      end

      it "returns the right values on a successful create" do
        post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), admin_headers
        model_instance = TestModel.first
        url = "/v2/test_models/#{model_instance.guid}"

        expect(last_response.status).to eq(201)
        expect(last_response.location).to eq(url)
        expect(decoded_response["metadata"]["url"]).to eq(url)
        expect(decoded_response["entity"]["unique_value"]).to eq("foobar")
      end
    end

    describe "#read" do
      context "when the guid matches a record" do
        let!(:model) { TestModel.make }

        it "returns not authorized if user does not have access" do
          get "/v2/test_models/#{model.guid}", "", headers_for(user)

          expect(decoded_response["code"]).to eq(10003)
          expect(decoded_response["description"]).to match(/not authorized/)
        end

        it "returns the serialized object if access is validated" do
          RestController::ObjectRenderer.any_instance.
            should_receive(:render_json).
            with(TestModelsController, model, {}).
            and_return("serialized json")

          get "/v2/test_models/#{model.guid}", "", admin_headers

          expect(last_response.body).to eq("serialized json")
        end
      end
    end

    describe "#update" do
      context "when the guid matches a record" do
        let!(:model) { TestModel.make }

        it "returns not authorized if the user does not have access " do
          put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({unique_value: "something"}), headers_for(user)

          expect(model.reload.unique_value).not_to eq("something")
          expect(decoded_response["code"]).to eq(10003)
          expect(decoded_response["description"]).to match(/not authorized/)
        end

        it "prevents other processes from updating the same row until the transaction finishes" do
          TestModel.stub(:find).with(:guid => model.guid).and_return(model)
          model.should_receive(:lock!).ordered
          model.should_receive(:update_from_hash).ordered.and_call_original

          put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({unique_value: "something"}), admin_headers
        end

        it "returns the serialized updated object if access is validated" do
          RestController::ObjectRenderer.any_instance.
            should_receive(:render_json).
            with(TestModelsController, instance_of(TestModel), {}).
            and_return("serialized json")

          put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({}), admin_headers

          expect(last_response.status).to eq(201)
          expect(last_response.body).to eq("serialized json")
        end

        it "updates the data" do
          expect(model.updated_at).to be_nil

          put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({unique_value: "new value"}), admin_headers

          model.reload
          expect(model.updated_at).not_to be_nil
          expect(model.unique_value).to eq("new value")
        end

        it "calls the hooks in the right order" do
          calls = []

          TestModelsController.any_instance.should_receive(:before_update).with(model) do
            calls << :before_update
          end
          TestModel.any_instance.should_receive(:update_from_hash) do
            calls << :update_from_hash
            model
          end
          TestModelsController.any_instance.should_receive(:after_update).with(instance_of(TestModel)) do
            calls << :after_update
          end

          put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({unique_value: "new value"}), admin_headers

          expect(calls).to eq([:before_update, :update_from_hash, :after_update])
        end
      end
    end

    describe "#do_delete" do
      let!(:model) { TestModel.make }
      let(:params) { {} }

      def query_params
        params.to_a.collect{|pair| pair.join("=")}.join("&")
      end

      shared_examples "tests with associations" do
        context "with associated models" do
          let(:test_model_nullify_dep) { TestModelNullifyDep.create }

          before do
            model.add_test_model_destroy_dep TestModelDestroyDep.create
            model.add_test_model_nullify_dep test_model_nullify_dep
          end

          context "when deleting with recursive set to true" do
            def run_delayed_job
              Delayed::Worker.new.work_off if Delayed::Job.last
            end

            before { params.merge!("recursive" => "true") }

            it "successfully deletes" do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers
                run_delayed_job
              }.to change {
                TestModel.count
              }.by(-1)
            end

            it "successfully deletes association marked for destroy" do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers
                run_delayed_job
              }.to change {
                TestModelDestroyDep.count
              }.by(-1)
            end

            it "successfully nullifies association marked for nullify" do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers
                run_delayed_job
              }.to change {
                test_model_nullify_dep.reload.test_model_id
              }.from(model.id).to(nil)
            end
          end

          context "when deleting non-recursively" do
            it "raises an association error" do
              delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers
              expect(last_response.status).to eq(400)
              expect(decoded_response["code"]).to eq(10006)
              expect(decoded_response["description"]).to match(/associations/)
            end
          end
        end
      end

      context "when sync" do
        it "deletes the object" do
          expect {
            delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers
          }.to change {
            TestModel.count
          }.by(-1)
        end

        it "returns a 204" do
          delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers

          expect(last_response.status).to eq(204)
          expect(last_response.body).to eq("")
        end

        include_examples "tests with associations"
      end

      context "when async" do
        let(:params) { {"async" => "true"} }

        context "and using the job enqueuer" do
          let(:job) { double(Jobs::Runtime::ModelDeletion) }
          let(:enqueuer) { double(Jobs::Enqueuer) }
          let(:presenter) { double(JobPresenter) }

          it "returns a 202 with the job information" do
            delete "/v2/test_models/#{model.guid}?#{query_params}", "", admin_headers

            expect(last_response.status).to eq(202)
            job_id = decoded_response["entity"]["guid"]
            expect(Delayed::Job.where(guid: job_id).first).to exist
          end
        end

        include_examples "tests with associations"
      end
    end

    describe "#enumerate" do
      before do
        TestModel.make
      end

      it "paginates the dataset with query params" do
        RestController::PaginatedCollectionRenderer.any_instance
          .should_receive(:render_json).with(
            TestModelsController,
            anything,
            anything,
            anything,
            anything,
        ).and_call_original

        get "/v2/test_models", "", admin_headers
        expect(last_response.status).to eq(200)
        expect(decoded_response["total_results"]).to eq(1)
      end
    end

    describe "error handling" do
      describe "404" do
        before do
          VCAP::Errors::Details::HARD_CODED_DETAILS["TestModelNotFound"] = {
            'code' => 999999999,
            'http_code' => 404,
            'message' => "Test Model Not Found",
          }
        end

        it "returns not found for reads" do
          get "/v2/test_models/99999", "", admin_headers
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end

        it "returns not found for updates" do
          put "/v2/test_models/99999", {}, admin_headers
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end

        it "returns not found for deletes" do
          delete "/v2/test_models/99999", "", admin_headers
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end
      end

      describe "model errors" do
        before do
          VCAP::Errors::Details::HARD_CODED_DETAILS["TestModelValidation"] = {
            'code' => 999999998,
            'http_code' => 400,
            'message' => "Validation Error",
          }
        end

        it "returns 400 error for missing attributes; returns a request-id and no location" do
          post "/v2/test_models", "{}", admin_headers
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 1001
          decoded_response["description"].should match(/invalid/)
          last_response.location.should be_nil
          last_response.headers["X-VCAP-Request-ID"].should_not be_nil
        end

        it "returns 400 error when validation fails on create" do
          TestModel.make(unique_value: 'unique')
          post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: 'unique'}), admin_headers
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 999999998
          decoded_response["description"].should match(/Validation Error/)
        end

        it "returns 400 error when validation fails on update" do
          TestModel.make(unique_value: 'unique')
          test_model = TestModel.make(unique_value: 'not-unique')
          put "/v2/test_models/#{test_model.guid}", Yajl::Encoder.encode({unique_value: 'unique'}), admin_headers
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 999999998
          decoded_response["description"].should match(/Validation Error/)
        end
      end

      describe "auth errors" do
        context "with invalid auth header" do
          let(:headers) do
            headers = headers_for(user)
            headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
            headers
          end

          it "returns an error" do
            get "/v2/test_models", "", headers
            expect(last_response.status).to eq 401
            expect(decoded_response["code"]).to eq 1000
            decoded_response["description"].should match(/Invalid Auth Token/)
          end
        end
      end
    end

    describe "associated collections" do
      describe "to_many" do
        let(:model) { TestModel.make }
        let(:associated_model1) { TestModelManyToMany.make }
        let(:associated_model2) { TestModelManyToMany.make }
        let(:associated_model3) { TestModelManyToMany.make }

        describe "update" do
          it "allows associating nested models" do
            put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({test_model_many_to_many_guids: [associated_model1.guid, associated_model2.guid]}), admin_headers
            expect(last_response.status).to eq(201)
            model.reload
            expect(model.test_model_many_to_manies).to include(associated_model1)
            expect(model.test_model_many_to_manies).to include(associated_model2)
          end

          context "with existing models in the association" do
            before { model.add_test_model_many_to_many associated_model1 }

            it "replaces existing associated models" do
              put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({test_model_many_to_many_guids: [associated_model2.guid]}), admin_headers
              expect(last_response.status).to eq(201)
              model.reload
              expect(model.test_model_many_to_manies).not_to include(associated_model1)
              expect(model.test_model_many_to_manies).to include(associated_model2)
            end

            it "removes associated models when empty array is provided" do
              put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({test_model_many_to_many_guids: []}), admin_headers
              expect(last_response.status).to eq(201)
              model.reload
              expect(model.test_model_many_to_manies).not_to include(associated_model1)
            end

            it "ignores invalid guids" do
              put "/v2/test_models/#{model.guid}", Yajl::Encoder.encode({test_model_many_to_many_guids: [associated_model2.guid, 'abcd']}), admin_headers
              expect(last_response.status).to eq(201)
              model.reload
              expect(model.test_model_many_to_manies.length).to eq(1)
              expect(model.test_model_many_to_manies).to include(associated_model2)
            end
          end
        end

        describe "reading" do
          context "with no associated records" do
            it "returns an empty collection" do
              get "/v2/test_models/#{model.guid}/test_model_many_to_manies", "", admin_headers

              expect(last_response.status).to eq(200)
              expect(decoded_response["total_results"]).to eq(0)
              expect(decoded_response).to have_key("prev_url")
              expect(decoded_response["prev_url"]).to be_nil
              expect(decoded_response).to have_key("next_url")
              expect(decoded_response["next_url"]).to be_nil
              expect(decoded_response["resources"]).to eq []
            end
          end

          context "with associated records" do
            before do
              model.add_test_model_many_to_many associated_model1
              model.add_test_model_many_to_many associated_model2
              model.add_test_model_many_to_many associated_model3
            end

            it "returns collection response" do
              get "/v2/test_models/#{model.guid}/test_model_many_to_manies?results-per-page=2", "", admin_headers

              expect(last_response.status).to eq(200)
              expect(decoded_response["total_results"]).to eq(3)
              expect(decoded_response).to have_key("prev_url")
              expect(decoded_response["prev_url"]).to be_nil
              expect(decoded_response["next_url"]).to include("page=2&results-per-page=2")
              found_guids = decoded_response["resources"].collect {|resource| resource["metadata"]["guid"]}
              expect(found_guids).to match_array([associated_model1.guid, associated_model2.guid])
            end

            it "returns other pages when requested" do
              get "/v2/test_models/#{model.guid}/test_model_many_to_manies?page=2&results-per-page=2", "", admin_headers

              expect(last_response.status).to eq(200)
              expect(decoded_response["total_results"]).to eq(3)
              expect(decoded_response["prev_url"]).to include("page=1&results-per-page=2")
              expect(decoded_response).to have_key("next_url")
              expect(decoded_response["next_url"]).to be_nil
              found_guids = decoded_response["resources"].collect {|resource| resource["metadata"]["guid"]}
              expect(found_guids).to match_array([associated_model3.guid])
            end
          end

          describe "inline-relations-depth" do
            before { model.add_test_model_many_to_many associated_model1 }

            context "when depth is not set" do
              it "does not return relations inline" do
                get "/v2/test_models/#{model.guid}", "", admin_headers
                expect(entity).to have_key "test_model_many_to_manies_url"
                expect(entity).to_not have_key "test_model_many_to_manies"
              end
            end

            context "when depth is 0" do
              it "does not return relations inline" do
                get "/v2/test_models/#{model.guid}?inline-relations-depth=0", "", admin_headers
                expect(entity).to have_key "test_model_many_to_manies_url"
                expect(entity).to_not have_key "test_model_many_to_manies"
              end
            end

            context "when depth is 1" do
              it "returns nested relations" do
                get "/v2/test_models/#{model.guid}?inline-relations-depth=1", "", admin_headers
                expect(entity).to have_key "test_model_many_to_manies_url"
                expect(entity).to have_key "test_model_many_to_manies"
              end
            end
          end
        end
      end

      describe "to_one" do
        let(:model) { TestModelManyToOne.make }
        let(:associated_model) { TestModel.make }

        before do
          model.test_model = associated_model
          model.save
        end

        describe "reading" do
          describe "inline-relations-depth" do
            context "when depth is not set" do
              it "does not return relations inline" do
                get "/v2/test_model_many_to_ones/#{model.guid}", "", admin_headers
                expect(entity).to have_key "test_model_url"
                expect(entity).to have_key "test_model_guid"
                expect(entity).to_not have_key "test_model"
              end
            end

            context "when depth is 0" do
              it "does not return relations inline" do
                get "/v2/test_model_many_to_ones/#{model.guid}?inline-relations-depth=0", "", admin_headers
                expect(entity).to have_key "test_model_url"
                expect(entity).to have_key "test_model_guid"
                expect(entity).to_not have_key "test_model"
              end
            end

            context "when depth is 1" do
              it "returns nested relations" do
                get "/v2/test_model_many_to_ones/#{model.guid}?inline-relations-depth=1", "", admin_headers
                expect(entity).to have_key "test_model_url"
                expect(entity).to have_key "test_model_guid"
                expect(entity).to have_key "test_model"
              end
            end
          end
        end
      end
    end
  end
end

require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CrashesController do
    describe "GET /v2/apps/:id/crashes" do
      before :each do
        @app = AppFactory.make
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        let(:instances_reporter) { double(:instances_reporter) }
        let(:crashed_instances) do
          [
            { :instance => "instance_1", :since => 1 },
            { :instance => "instance_2", :since => 1 },
          ]
        end

        before do
          instances_reporter_factory = CloudController::DependencyLocator.instance.instances_reporter_factory
          allow(instances_reporter_factory).to receive(:instances_reporter_for_app).and_return(instances_reporter)
          allow(instances_reporter).to receive(:crashed_instances_for_app).and_return(crashed_instances)
        end

        it "should return the crashed instances" do
          expected = [
                      { "instance" => "instance_1", "since" => 1 },
                      { "instance" => "instance_2", "since" => 1 },

                     ]

          get("/v2/apps/#{@app.guid}/crashes", {}, headers_for(@developer))

          last_response.status.should == 200
          Yajl::Parser.parse(last_response.body).should == expected
          expect(instances_reporter).to have_received(:crashed_instances_for_app).with(
            satisfy {  |requested_app| requested_app.guid == @app.guid })
        end
      end

      context "as a user" do
        it "should return 403" do
          get("/v2/apps/#{@app.guid}/crashes",
              {},
              headers_for(@user))

              last_response.status.should == 403
        end
      end
    end
  end
end

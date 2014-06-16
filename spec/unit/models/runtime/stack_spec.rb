require "spec_helper"

module VCAP::CloudController
  describe Stack, type: :model do
    let(:file) { File.join(Paths::FIXTURES, "config/stacks.yml") }
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
      :one_to_zero_or_more => {
        :apps              => {
          :delete_ok => true,
          :create_for => lambda { |stack| AppFactory.make(:stack => stack) }
        },
      },
    }

    describe ".configure" do
      context "with valid config" do
        it "can load" do
          Stack.configure(file)
        end
      end

      context "with invalid config" do
        let(:file) { File.join(Paths::FIXTURES, "config/invalid_stacks.yml") }

        {:default => "default => Missing key",
         :stacks => "name => Missing key"
        }.each do |key, expected_error|
          it "requires #{key} (validates via '#{expected_error}')" do
            expect {
              Stack.configure(file)
            }.to raise_error(Membrane::SchemaValidationError, /#{expected_error}/)
          end
        end
      end
    end

    describe ".populate" do
      context "when config was not set" do
        before { Stack.configure(nil) }

        it "raises config not specified error" do
          expect {
            Stack.default
          }.to raise_error(Stack::MissingConfigFileError)
        end
      end

      context "when config was set" do
        before { Stack.configure(file) }

        context "when there are no stacks" do
          before { Stack.dataset.destroy }

          it "creates them all" do
            Stack.populate

            cider = Stack.find(:name => "cider")
            expect(cider.description).to eq("cider-description")

            default_stack = Stack.find(:name => "default-stack-name")
            expect(default_stack.description).to eq("default-stack-description")
          end

          context "when there are existing stacks" do
            before do
              Stack.dataset.destroy
              Stack.populate
            end

            it "should not create duplicates" do
              expect { Stack.populate }.not_to change { Stack.count }
            end

            context "and the config file would change an existing stack" do
              it "should warn" do
                cider = Stack.find(name: "cider")
                cider.description = "cider-description has changed"
                cider.save


                mock_logger = double
                Steno.stub(:logger).and_return(mock_logger)

                mock_logger.should_receive(:warn).with("stack.populate.collision", "name" => "cider", "description" => "cider-description")

                Stack.populate
              end
            end
          end
        end
      end
    end

    describe ".default" do
      before { Stack.configure(file) }

      context "when config was not set" do
        before { Stack.configure(nil) }

        it "raises config not specified error" do
          expect {
            Stack.default
          }.to raise_error(Stack::MissingConfigFileError)
        end
      end

      context "when config was set" do
        before { Stack.dataset.destroy }

        context "when stack is found with default name" do
          before { Stack.make(:name => "default-stack-name") }

          it "returns found stack" do
            Stack.default.name.should == "default-stack-name"
          end
        end

        context "when stack is not found with default name" do
          it "raises MissingDefaultStack" do
            expect {
              Stack.default
            }.to raise_error(Stack::MissingDefaultStackError, /default-stack-name/)
          end
        end
      end
    end

    describe "#destroy" do
      let(:stack) { Stack.make }

      it "destroys the apps" do
        app = AppFactory.make(:stack => stack)
        expect { stack.destroy(savepoint: true) }.to change { App.where(:id => app.id).count }.by(-1)
      end
    end
  end
end

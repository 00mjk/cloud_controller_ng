shared_context "collections" do |opts, attr|
  let(:obj) do
    opts[:model].make
  end

  let(:child_name) do
    attr.to_s.singularize
  end

  let(:add_method) do
    "add_#{child_name}"
  end

  let(:get_method) do
    "#{child_name}s"
  end

  let(:headers) do
    json_headers(admin_headers)
  end

  before do
    @opts = opts
    @attr = attr
  end
end

shared_context "inlined_relations_context" do |opts, attr, make, depth|
  before do
    query_parms = query_params_for_inline_depth(depth)
    get "#{opts[:path]}/#{obj.guid}", query_parms, headers
    @uri = entity["#{attr}_url"]
  end
end

shared_examples "inlined_relations" do |attr, depth|
  attr = attr.to_s

  it "should return a relative uri in the #{attr}_url field" do
    @uri.should_not be_nil
  end

  if depth.nil? || depth == 0
    it "should not return a #{attr} field" do
      entity.should_not have_key(attr)
    end
  else
    it "should return a #{attr} field" do
      entity.should have_key(attr)
    end
  end
end

shared_examples "get to_many attr url" do |opts, attr, make|
  describe "GET on the #{attr}_url" do
    describe "with no associated #{attr}" do
      before do
        obj.send("remove_all_#{attr}")
        get @uri, {}, headers
      end

      it "returns empty collection response" do
        last_response.status.should == 200

        decoded_response["total_results"].should == 0

        decoded_response.should have_key("prev_url")
        decoded_response["prev_url"].should be_nil

        decoded_response.should have_key("next_url")
        decoded_response["next_url"].should be_nil

        decoded_response["resources"].should == []
      end
    end

    describe "with 2 associated #{attr}" do
      before do
        obj.send("remove_all_#{attr}")
        @child1 = make.call(obj)
        @child2 = make.call(obj)

        obj.send(add_method, @child1)
        obj.send(add_method, @child2)
        obj.save

        get @uri, {}, headers
      end

      it "returns collection response with two results" do
        last_response.status.should == 200

        decoded_response["total_results"].should == 2

        decoded_response.should have_key("prev_url")
        decoded_response["prev_url"].should be_nil

        decoded_response.should have_key("next_url")
        decoded_response["next_url"].should be_nil

        os = VCAP::CloudController::RestController::PreloadedObjectSerializer.new
        ar = opts[:model].association_reflection(attr)
        child_controller = VCAP::CloudController.controller_from_model_name(ar.associated_class.name)

        c1 = normalize_attributes(os.serialize(child_controller, @child1, {}))
        c2 = normalize_attributes(os.serialize(child_controller, @child2, {}))

        decoded_response["resources"].size.should == 2
        decoded_response["resources"].should =~ [c1, c2]
      end
    end
  end
end

shared_examples "collection operations" do |opts|
  describe "collections" do
    describe "reading collections" do
      describe "many_to_many, one_to_many" do
        to_many_attrs = opts[:many_to_many_collection_ids].merge(opts[:one_to_many_collection_ids])
        to_many_attrs.each do |attr, make|
          path = "#{opts[:path]}/:guid"

          [nil, 0, 1].each do |inline_relations_depth|
            desc = ControllerHelpers.description_for_inline_depth(inline_relations_depth)
            describe "GET #{path}#{desc}" do
              include_context "collections", opts, attr
              include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
              include_examples "inlined_relations", attr, inline_relations_depth
              include_examples "get to_many attr url", opts, attr, make
            end
          end

          describe "with 3 associated #{attr}" do
            depth = 1
            pagination = 2
            desc = ControllerHelpers.description_for_inline_depth(depth, pagination)
            describe "GET #{path}#{desc}" do
              include_context "collections", opts, attr

              let(:query_params) { query_params_for_inline_depth(depth, pagination) }

              before do
                obj.send("remove_all_#{attr}")
                3.times do
                  child = make.call(obj)
                  obj.refresh
                  obj.send(add_method, child)
                end

                get "#{opts[:path]}/#{obj.guid}", query_params, headers
                @uri = entity["#{attr}_url"]
              end

              # we want to make sure to only limit the assocation that
              # has too many results yet still inline the others
              context "when inline depth = 0" do
                let(:query_params) { {} }
                include_examples "inlined_relations", attr
              end
              (to_many_attrs.keys - [attr]).each do |other_attr|
                include_examples "inlined_relations", other_attr, depth
              end

              describe "GET on the #{attr}_url" do
                before do
                  get @uri, query_params, headers

                  @raw_guids = obj.send(get_method).sort do |a, b|
                    a[:id] <=> b[:id]
                  end.map { |o| o.guid }
                end

                it "returns the collection response" do
                  last_response.status.should == 200

                  decoded_response["total_results"].should == 3

                  decoded_response.should have_key("prev_url")
                  decoded_response["prev_url"].should be_nil

                  decoded_response.should have_key("next_url")
                  next_url = decoded_response["next_url"]
                  next_url.should match /#{@uri}\?/
                  next_url.should include("page=2&results-per-page=2")

                  decoded_response["resources"].count.should == 2
                  api_guids = decoded_response["resources"].map do |v|
                    v["metadata"]["guid"]
                  end

                  api_guids.should == @raw_guids[0..1]
                end

                it "should return the next 1 resource when fetching next_url" do
                  query_parms = query_params_for_inline_depth(depth)
                  get decoded_response["next_url"], query_parms, headers
                  last_response.status.should == 200
                  decoded_response["resources"].count.should == 1
                  guid = decoded_response["resources"][0]["metadata"]["guid"]
                  guid.should == @raw_guids[2]
                end
              end
            end
          end
        end
      end

      describe "many_to_one" do
        opts[:many_to_one_collection_ids].each do |attr, make|
          path = "#{opts[:path]}/:guid"

          [nil, 0, 1].each do |inline_relations_depth|
            desc = ControllerHelpers.description_for_inline_depth(inline_relations_depth)
            describe "GET #{path}#{desc}" do
              include_context "collections", opts, attr

              before do
                obj.send("#{attr}=", make.call(obj)) unless obj.send(attr)
                obj.save
              end

              include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
              include_examples "inlined_relations", attr, inline_relations_depth

              it "should return a #{attr}_guid field" do
                entity.should have_key("#{attr}_guid")
              end

              # this is basically the read api, so we'll do most of the
              # detailed read testing there
              desc = ControllerHelpers.description_for_inline_depth(inline_relations_depth)
              describe "GET on the #{attr}_url" do
                before do
                  get @uri, {}, headers
                end

                it "should return 200" do
                  last_response.status.should == 200
                end
              end
            end
          end
        end
      end
    end
  end
end

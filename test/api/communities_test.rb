require_relative 'test_helper'

class CommunitiesTest < ActiveSupport::TestCase

  def setup
    Community.delete_all
    create_and_activate_user
  end

  should 'list only communities to logged user' do
    login_api
    community = fast_create(Community, :environment_id => environment.id)
    enterprise = fast_create(Enterprise, :environment_id => environment.id) # should not list this enterprise

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_not_includes json['communities'].map {|c| c['id']}, enterprise.id
    assert_includes json['communities'].map {|c| c['id']}, community.id
  end

  should 'list all communities to logged user' do
    login_api
    community1 = fast_create(Community, :environment_id => environment.id, :public_profile => true)
    community2 = fast_create(Community, :environment_id => environment.id)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id, community2.id], json['communities'].map {|c| c['id']}
  end

  should 'not list invisible communities to logged user' do
    login_api
    community1 = fast_create(Community, :environment_id => environment.id)
    fast_create(Community, :environment_id => environment.id, :visible => false)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal [community1.id], json['communities'].map {|c| c['id']}
  end

  should 'list private communities to logged user' do
    login_api
    community1 = fast_create(Community, :environment_id => environment.id)
    community2 = fast_create(Community, :environment_id => environment.id, :public_profile => false)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id, community2.id], json['communities'].map {|c| c['id']}
  end

  should 'list private communities to logged members' do
    login_api
    community1 = fast_create(Community, :environment_id => environment.id)
    community2 = fast_create(Community, :environment_id => environment.id, :public_profile => false)
    community2.add_member(person)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id, community2.id], json['communities'].map {|c| c['id']}
  end

  should 'create a community with logged user' do
    login_api
    params[:community] = {:name => 'some'}
    post "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal 'some', json['community']['name']
  end

  should 'return 400 status for invalid community creation to logged user ' do
    login_api
    post "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal 400, last_response.status
  end

  should 'get community to logged user' do
    login_api
    community = fast_create(Community, :environment_id => environment.id)

    get "/api/v1/communities/#{community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['community']['id']
  end

  should 'not list invisible community to logged users' do
    login_api
    community = fast_create(Community, :environment_id => environment.id, :visible => false)

    get "/api/v1/communities/#{community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)

    assert_nil json["community"]
  end

  should 'not get private community content to non member' do
    login_api
    community = fast_create(Community, :environment_id => environment.id, :public_profile => false)

    get "/api/v1/communities/#{community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['community']['id']
    assert_nil json['community']['members']
  end

  should 'get private community to logged member' do
    login_api
    community = fast_create(Community, :environment_id => environment.id, :public_profile => false, :visible => true)
    community.add_member(person)

    get "/api/v1/communities/#{community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['community']['id']
    assert_not_nil json['community']['members']
  end

  should 'list person communities to logged user' do
    login_api
    community = fast_create(Community, :environment_id => environment.id)
    fast_create(Community, :environment_id => environment.id)
    community.add_member(person)

    get "/api/v1/people/#{person.id}/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community.id], json['communities'].map {|c| c['id']}
  end

  should 'not list person invisible communities to logged user' do
    login_api
    community1 = fast_create(Community, :environment_id => environment.id)
    community2 = fast_create(Community, :environment_id => environment.id, :visible => false)
    community1.add_member(person)
    community2.add_member(person)

    get "/api/v1/people/#{person.id}/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id], json['communities'].map {|c| c['id']}
  end

  should 'logged user list communities with pagination' do
    login_api
    community1 = fast_create(Community, :public_profile => true, :created_at => 1.day.ago)
    community2 = fast_create(Community, :created_at => 2.days.ago)

    params[:page] = 2
    params[:per_page] = 1
    get "/api/v1/communities?#{params.to_query}"
    json_page_two = JSON.parse(last_response.body)

    params[:page] = 1
    params[:per_page] = 1
    get "/api/v1/communities?#{params.to_query}"
    json_page_one = JSON.parse(last_response.body)

    assert_includes json_page_one["communities"].map { |a| a["id"] }, community1.id
    assert_not_includes json_page_one["communities"].map { |a| a["id"] }, community2.id

    assert_includes json_page_two["communities"].map { |a| a["id"] }, community2.id
    assert_not_includes json_page_two["communities"].map { |a| a["id"] }, community1.id
  end

  should 'list communities with timestamp to logged user' do
    login_api
    community1 = fast_create(Community, :public_profile => true)
    community2 = fast_create(Community)

    community1.updated_at = Time.now.in_time_zone + 3.hours
    community1.save!

    params[:timestamp] = Time.now.in_time_zone + 1.hours
    get "/api/v1/communities/?#{params.to_query}"
    json = JSON.parse(last_response.body)

    assert_includes json["communities"].map { |a| a["id"] }, community1.id
    assert_not_includes json["communities"].map { |a| a["id"] }, community2.id
  end

  should 'anonymous list only communities' do
    community = fast_create(Community, :environment_id => environment.id)
    enterprise = fast_create(Enterprise, :environment_id => environment.id) # should not list this enterprise

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_not_includes json['communities'].map {|c| c['id']}, enterprise.id
    assert_includes json['communities'].map {|c| c['id']}, community.id
  end

  should 'anonymous list all communities' do
    community1 = fast_create(Community, :environment_id => environment.id, :public_profile => true)
    community2 = fast_create(Community, :environment_id => environment.id)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id, community2.id], json['communities'].map {|c| c['id']}
  end

  should 'not list invisible communities to anonymous' do
    community1 = fast_create(Community, :environment_id => environment.id)
    fast_create(Community, :environment_id => environment.id, :visible => false)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal [community1.id], json['communities'].map {|c| c['id']}
  end

  should 'list all visible communities except secret ones to anonymous' do
    community = fast_create(Community, :environment_id => environment.id)
    private_community = fast_create(Community, :environment_id => environment.id, :public_profile => false)
    secret_community = fast_create(Community, :environment_id => environment.id, :public_profile => false, :secret => true)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community.id, private_community.id], json['communities'].map {|c| c['id']}
  end

  should 'list private communities to anonymous' do
    community1 = fast_create(Community, :environment_id => environment.id)
    community2 = fast_create(Community, :environment_id => environment.id, :public_profile => false)

    get "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community1.id, community2.id], json['communities'].map {|c| c['id']}
  end

  should 'not create a community as an anonymous user' do
    params[:community] = {:name => 'some'}

    post "/api/v1/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal 401, last_response.status
  end

  should 'get community for anonymous' do
    community = fast_create(Community, :environment_id => environment.id)
    get "/api/v1/communities/#{community.id}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['community']['id']
  end

  should 'not get invisible community to anonymous user' do
    community = fast_create(Community, :environment_id => environment.id, :visible => false)
    get "/api/v1/communities/#{community.id}"
    json = JSON.parse(last_response.body)
    assert json['community'].blank?
  end

  should 'get private community to anonymous user' do
    community = fast_create(Community, :environment_id => environment.id, :public_profile => false)

    get "/api/v1/communities/#{community.id}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['community']['id']
    assert_nil json['community']['members']
  end

  should 'list public person communities to anonymous' do
    community = fast_create(Community, :environment_id => environment.id)
    fast_create(Community, :environment_id => environment.id)
    community.add_member(person)

    get "/api/v1/people/#{person.id}/communities?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [community.id], json['communities'].map {|c| c['id']}
  end

  should 'not list private person communities to anonymous' do
    community = fast_create(Community, :environment_id => environment.id)
    fast_create(Community, :environment_id => environment.id)
    person.public_profile = false
    person.save
    community.add_member(person)

    get "/api/v1/people/#{person.id}/communities?#{params.to_query}"
    assert_equal 403, last_response.status
  end

  should 'list communities with pagination to anonymous' do
    community1 = fast_create(Community, :public_profile => true, :created_at => 1.day.ago)
    community2 = fast_create(Community, :created_at => 2.days.ago)

    params[:page] = 2
    params[:per_page] = 1
    get "/api/v1/communities?#{params.to_query}"
    json_page_two = JSON.parse(last_response.body)

    params[:page] = 1
    params[:per_page] = 1
    get "/api/v1/communities?#{params.to_query}"
    json_page_one = JSON.parse(last_response.body)

    assert_includes json_page_one["communities"].map { |a| a["id"] }, community1.id
    assert_not_includes json_page_one["communities"].map { |a| a["id"] }, community2.id

    assert_includes json_page_two["communities"].map { |a| a["id"] }, community2.id
    assert_not_includes json_page_two["communities"].map { |a| a["id"] }, community1.id
  end

  should 'list communities with timestamp to anonymous ' do
    community1 = fast_create(Community, :public_profile => true)
    community2 = fast_create(Community)

    community1.updated_at = Time.now.in_time_zone + 3.hours
    community1.save!

    params[:timestamp] = Time.now.in_time_zone + 1.hours
    get "/api/v1/communities/?#{params.to_query}"
    json = JSON.parse(last_response.body)

    assert_includes json["communities"].map { |a| a["id"] }, community1.id
    assert_not_includes json["communities"].map { |a| a["id"] }, community2.id
  end

  should 'display public custom fields to anonymous' do
    CustomField.create!(:name => "Rating", :format => "string", :customized_type => "Community", :active => true, :environment => Environment.default)
    some_community = fast_create(Community)
    some_community.custom_values = { "Rating" => { "value" => "Five stars", "public" => "true"} }
    some_community.save!

    get "/api/v1/communities/#{some_community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert json['community']['additional_data'].has_key?('Rating')
    assert_equal "Five stars", json['community']['additional_data']['Rating']
  end

  should 'not display private custom fields to anonymous' do
    CustomField.create!(:name => "Rating", :format => "string", :customized_type => "Community", :active => true, :environment => Environment.default)
    some_community = fast_create(Community)
    some_community.custom_values = { "Rating" => { "value" => "Five stars", "public" => "false"} }
    some_community.save!

    get "/api/v1/communities/#{some_community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    refute json['community']['additional_data'].has_key?('Rating')
  end

	should 'add categories by id to community' do
		login_api
		category_1 = fast_create(Category, :environment_id => environment.id)
		category_2 = fast_create(Category, :environment_id => environment.id)
		params[:community] = {:name => 'some', :category_ids => "#{category_1.id},#{category_2.id}"}
		post "/api/v1/communities?#{params.to_query}"
		json = JSON.parse(last_response.body)
		assert json['community'].has_key?("categories")
		assert_equal json["community"]["categories"].length, 2
		assert_includes json["community"]["categories"][0].values, category_1.name
		assert_includes json["community"]["categories"][1].values, category_2.name
	end

	should 'add categories by name ids to community' do
		login_api
		category_1 = fast_create(Category, :environment_id => environment.id)
		category_2 = fast_create(Category, :environment_id => environment.id)
		params[:community] = {:name => 'some', :category_ids => "#{category_1.name},#{category_2.name}"}
		post "/api/v1/communities?#{params.to_query}"
		json = JSON.parse(last_response.body)
		assert json['community'].has_key?("categories")
		assert_equal json["community"]["categories"].length, 2
		assert_includes json["community"]["categories"][0].values, category_1.name
		assert_includes json["community"]["categories"][1].values, category_2.name
	end
end

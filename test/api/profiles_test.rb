require_relative 'test_helper'

class ProfilesTest < ActiveSupport::TestCase

  def setup
    Profile.delete_all
    create_and_activate_user
  end

  should 'logged user list all profiles' do
    login_api
    person1 = fast_create(Person)
    person2 = fast_create(Person)
    community = fast_create(Community)
    get "/api/v1/profiles?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equivalent [person.id, person1.id, person2.id, community.id], json.map {|p| p['id']}
  end

  should 'logged user get person from profile id' do
    login_api
    some_person = fast_create(Person)
    get "/api/v1/profiles/#{some_person.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal some_person.id, json['id']
  end

  should 'not get inexistent profile' do
    login_api
    get "/api/v1/profiles/invalid_id?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal 404, last_response.status
  end

  should 'logged user get community from profile id' do
    login_api
    community = fast_create(Community)
    get "/api/v1/profiles/#{community.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['id']
  end

  group_kinds = %w(community enterprise)
  group_kinds.each do |kind|
    should "delete #{kind} from profile id with permission" do
      login_api
      profile = fast_create(kind.camelcase.constantize, :environment_id => environment.id)
      give_permission(@person, 'destroy_profile', profile)
      assert_not_nil Profile.find_by_id profile.id

      delete "/api/v1/profiles/#{profile.id}?#{params.to_query}"

      assert_equal 200, last_response.status
      assert_nil Profile.find_by_id profile.id
    end

    should "not delete #{kind} from profile id without permission" do
      login_api
      profile = fast_create(kind.camelcase.constantize, :environment_id => environment.id)
      assert_not_nil Profile.find_by_id profile.id

      delete "/api/v1/profiles/#{profile.id}?#{params.to_query}"

      assert_equal 403, last_response.status
      assert_not_nil Profile.find_by_id profile.id
    end
  end

  should 'person delete itself' do
    login_api
    delete "/api/v1/profiles/#{@person.id}?#{params.to_query}"
    assert_equal 200, last_response.status
    assert_nil Profile.find_by_id @person.id
  end

  should 'only admin delete other people' do
    login_api
    profile = fast_create(Person, :environment_id => environment.id)
    assert_not_nil Profile.find_by_id profile.id

    delete "/api/v1/profiles/#{profile.id}?#{params.to_query}"

    assert_equal 403, last_response.status
    assert_not_nil Profile.find_by_id profile.id

    environment.add_admin(@person)

    delete "/api/v1/profiles/#{profile.id}?#{params.to_query}"

    assert_equal 200, last_response.status
    assert_nil Profile.find_by_id profile.id

  end

  should 'anonymous user access delete action' do
    profile = fast_create(Person, :environment_id => environment.id)

    delete "/api/v1/profiles/#{profile.id}?#{params.to_query}"
    assert_equal 401, last_response.status
    assert_not_nil Profile.find_by_id profile.id
  end

  should 'anonymous list all profiles' do
    person1 = fast_create(Person)
    person2 = fast_create(Person)
    community = fast_create(Community)
    get "/api/v1/profiles"
    json = JSON.parse(last_response.body)
    assert_equivalent [person.id, person1.id, person2.id, community.id], json.map {|p| p['id']}
  end

  should 'anonymous get person from profile id' do
    some_person = fast_create(Person)
    get "/api/v1/profiles/#{some_person.id}"
    json = JSON.parse(last_response.body)
    assert_equal some_person.id, json['id']
  end

  should 'anonymous get community from profile id' do
    community = fast_create(Community)
    get "/api/v1/profiles/#{community.id}"
    json = JSON.parse(last_response.body)
    assert_equal community.id, json['id']
  end

  should 'display profile public fields to anonymous' do
    some_person = create_user('test', { :email => "lappis@unb.br" }).person
    Person.any_instance.stubs(:public_fields).returns(["email"])

    get "/api/v1/profiles/#{some_person.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert json['additional_data'].has_key?('email')
    assert_equal "lappis@unb.br", json['additional_data']['email']
  end

  should 'not display private fields to anonymous' do
    some_person = create_user('test', { :email => "lappis@unb.br" }).person

    get "/api/v1/profiles/#{some_person.id}/?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert !json['additional_data'].has_key?('email')
  end

  should 'display public custom fields to anonymous' do
    CustomField.create!(:name => "Rating", :format => "string", :customized_type => "Profile", :active => true, :environment => Environment.default)
    some_profile = fast_create(Profile)
    some_profile.custom_values = { "Rating" => { "value" => "Five stars", "public" => "true"} }
    some_profile.save!

    get "/api/v1/profiles/#{some_profile.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert json['additional_data'].has_key?('Rating')
    assert_equal "Five stars", json['additional_data']['Rating']
  end

  should 'not display private custom fields to anonymous' do
    CustomField.create!(:name => "Rating", :format => "string", :customized_type => "Profile", :active => true, :environment => Environment.default)
    some_profile = fast_create(Profile)
    some_profile.custom_values = { "Rating" => { "value" => "Five stars", "public" => "false"} }
    some_profile.save!

    get "/api/v1/profiles/#{some_profile.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    refute json.has_key?('Rating')
  end

  [Community, Enterprise].each do |klass|
    should "update #{klass.name}" do
      login_api
      profile = fast_create(klass)
      profile.add_admin(person)
      params[:profile] = {}
      params[:profile][:custom_header] = "Another Header"
      post "/api/v1/profiles/#{profile.id}?#{params.to_query}"
      assert_equal "Another Header", profile.reload.custom_header
    end

    should "not update a #{klass.name} if user does not have permission" do
      login_api
      profile = fast_create(klass)
      params[:profile] = {}
      params[:profile][:custom_header] = "Another Header"
      post "/api/v1/profiles/#{profile.id}?#{params.to_query}"
      assert_equal 403, last_response.status
    end

    should "not update a #{klass.name} if user is not logged in" do
      profile = fast_create(klass)
      params[:profile] = {}
      params[:profile][:custom_header] = "Another Header"
      post "/api/v1/profiles/#{profile.id}?#{params.to_query}"
      assert_equal 401, last_response.status
    end
  end

  should 'update person' do
    login_api
    params[:profile] = {}
    params[:profile][:custom_header] = "Another Header"
    post "/api/v1/profiles/#{person.id}?#{params.to_query}"
    assert_equal "Another Header", person.reload.custom_header
  end

  should 'not update person information if user does not have permission' do
    login_api
    profile = fast_create(Person)
    params[:profile] = {}
    params[:profile][:custom_header] = "Another Header"
    post "/api/v1/profiles/#{profile.id}?#{params.to_query}"
    assert_equal 403, last_response.status
  end

  should 'list profile permissions when get an article' do
    login_api
    profile = fast_create(Profile)
    give_permission(person, 'post_content', profile)
    get "/api/v1/profiles/#{profile.id}?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert_includes json["permissions"], 'allow_post_content'
  end
  should 'add categories by id to a specific profile' do
    login_api
    community = fast_create(Community)
    community.add_admin(person)
    community.save
    community.reload
    category_1 = fast_create(Category, :environment_id => environment.id)
    category_2 = fast_create(Category, :environment_id => environment.id)
    params.merge!({profile: {category_ids: "#{category_1.id},#{category_2.id}"}})
    post "/api/v1/profiles/#{community.id}/categories/?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert json.has_key?("categories")
    assert_equal json["categories"].length, 2
    assert_includes json["categories"][0].values, category_1.name
    assert_includes json["categories"][1].values, category_2.name
  end

  should 'add categories by name to a specific profile' do
    login_api
    community = fast_create(Community)
    community.add_admin(person)
    community.save
    community.reload
    category_1 = fast_create(Category, :environment_id => environment.id)
    category_2 = fast_create(Category, :environment_id => environment.id)
    params.merge!({profile: {category_ids: "#{category_1.name},#{category_2.name}"}})
    post "/api/v1/profiles/#{community.id}/categories/?#{params.to_query}"
    json = JSON.parse(last_response.body)
    assert json.has_key?("categories")
    assert_equal json["categories"].length, 2
    assert_includes json["categories"][0].values, category_1.name
    assert_includes json["categories"][1].values, category_2.name
  end
end

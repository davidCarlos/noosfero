# encoding: UTF-8
require_relative "../test_helper"

class ExternalPersonTest < ActiveSupport::TestCase
  fixtures :environments

  def setup
    @external_person = ExternalPerson.create!(identifier: 'johnlock',
                                     name: 'John Lock',
                                     source: 'anerenvironment.org',
                                     email: 'john@lock.org',
                                     created_at: Date.yesterday
                                    )
  end

  should 'have no permissions' do
    assert_equivalent [], @external_person.role_assignments
    refute @external_person.has_permission?(:manage_friends)
  end

  should 'have no suggested profiles' do
    assert_equivalent [], @external_person.suggested_communities
    assert_equivalent [], @external_person.suggested_people
    assert_equivalent [], @external_person.suggested_profiles
  end

  should 'have no friendships' do
    refute @external_person.add_friend(fast_create(Person))
    assert_equivalent [], @external_person.friendships
  end

  should 'not be a member of any communities' do
    community = fast_create(Community)
    refute community.add_member(@external_person)
    assert_equivalent [], @external_person.memberships
  end

  should 'not have any favorite enterprises' do
    assert_equivalent [], @external_person.favorite_enterprises
  end

  should 'be a person' do
    assert @external_person.person?
  end

  should 'not be a community, organization or enterprise' do
    refute @external_person.community?
    refute @external_person.enterprise?
    refute @external_person.organization?
  end

  should 'never be an admin for environments' do
    refute @external_person.is_admin?
    env = Environment.default
    env.add_admin @external_person
    refute @external_person.is_admin?(env)
    assert_equivalent [], env.admins
  end

  should 'redirect after login based on environment settings' do
    assert_respond_to ExternalPerson.new, :preferred_login_redirection
    environment = fast_create(Environment, :redirection_after_login => 'site_homepage')
    profile = fast_create(ExternalPerson, :environment_id => environment.id)
    assert_equal 'site_homepage', profile.preferred_login_redirection
  end

  should 'have an avatar from its original environment' do
    assert_match(/http:\/\/#{@external_person.source}\/.*/, @external_person.avatar)
  end

  should 'generate a custom profile icon based on its avatar' do
    assert_match(/http:\/\/#{@external_person.source}\/.*/, @external_person.profile_custom_icon)
  end

  should 'have an url to its profile on its original environment' do
    assert_match(/http:\/\/#{@external_person.source}\/profile\/.*/, @external_person.url)
  end

  should 'have a public profile url' do
    assert_match(/http:\/\/#{@external_person.source}\/profile\/.*/, @external_person.public_profile_url)
  end

  should 'have an admin url to its profile on its original environment' do
    assert_match(/http:\/\/#{@external_person.source}\/myprofile\/.*/, @external_person.admin_url)
  end

  should 'never be a friend of another person' do
    friend = fast_create(Person)
    friend.add_friend @external_person
    refute @external_person.is_a_friend?(friend)
    refute friend.is_a_friend?(@external_person)
  end

  should 'never send a friend request to another person' do
    friend = fast_create(Person)
    friend.add_friend @external_person
    refute friend.already_request_friendship?(@external_person)
    @external_person.add_friend(friend)
    refute @external_person.already_request_friendship?(friend)
  end

  should 'not follow another profile' do
    friend = fast_create(Person)
    friend.add_friend @external_person
    refute @external_person.follows?(friend)
    refute friend.follows?(@external_person)
  end

  should 'have an image' do
    assert_not_nil @external_person.image
  end

  should 'profile image has public filename and mimetype' do
    assert_not_nil @external_person.image.public_filename
    assert_not_nil @external_person.image.content_type
  end

  should 'respond to all instance methods in Profile' do
    methods = Profile.public_instance_methods(false)
    methods.each do |method|
      # We test if ExternalPerson responds to same methods as Profile, but we
      # skip methods generated by plugins, libs and validations, which are
      # usually only used internally
      assert_respond_to ExternalPerson.new, method.to_sym unless method =~ /type_name|^autosave_.*|^after_.*|^before_.*|validate_.*|^attribute_.*|.*_?tags?_?.*|^custom_value.*|^custom_context.*|^xss.*|bar/
    end
  end

  should 'respond to all instance methods in Person' do
    methods = Person.public_instance_methods(false)
    methods.each do |method|
      # We test if ExternalPerson responds to same methods as Person, but we
      # skip methods generated by plugins, libs and validations, which are
      # usually only used internally
      assert_respond_to ExternalPerson.new, method.to_sym unless method =~ /^autosave_.*|validate_.*|^before_.*|^after_.*|^assignment_.*|^(city|state)_.*/
    end
  end
end

require 'rack/test'

class SinatraAuthDataMapperTest < Minitest::Test

  include Rack::Test::Methods

  def setup
    post '/signup', TestHelper.gen_user
    follow_redirect!
    get '/logout'
  end

  def test_should_login
    post '/login', {'email' => TestHelper.gen_user['user[email]'], 'password' => TestHelper.gen_user['user[password]']}
    follow_redirect!

    assert_equal 'http://example.org/', last_request.url
    #assert cookie_jar['user']
    assert last_request.env['rack.session'][:user]
    assert last_response.ok?
  end

  def test_should_logout
    post '/login', {'email' => TestHelper.gen_user['user[email]'], 'password' => TestHelper.gen_user['user[password]']}
    get '/logout'
    follow_redirect!

    assert !last_request.env['rack.session'][:user]
    assert_equal 'http://example.org/', last_request.url
  end
end

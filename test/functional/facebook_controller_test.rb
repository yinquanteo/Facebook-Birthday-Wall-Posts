require 'test_helper'

class FacebookControllerTest < ActionController::TestCase
  test "should get sign_in" do
    get :sign_in
    assert_response :success
  end

  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get other" do
    get :other
    assert_response :success
  end

end

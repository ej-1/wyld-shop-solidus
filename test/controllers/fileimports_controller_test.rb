require 'test_helper'

class FileimportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fileimport = fileimports(:one)
  end

  test "should get index" do
    get fileimports_url
    assert_response :success
  end

  test "should get new" do
    get new_fileimport_url
    assert_response :success
  end

  test "should create fileimport" do
    assert_difference('Fileimport.count') do
      post fileimports_url, params: { fileimport: {  } }
    end

    assert_redirected_to fileimport_url(Fileimport.last)
  end

  test "should show fileimport" do
    get fileimport_url(@fileimport)
    assert_response :success
  end

  test "should get edit" do
    get edit_fileimport_url(@fileimport)
    assert_response :success
  end

  test "should update fileimport" do
    patch fileimport_url(@fileimport), params: { fileimport: {  } }
    assert_redirected_to fileimport_url(@fileimport)
  end

  test "should destroy fileimport" do
    assert_difference('Fileimport.count', -1) do
      delete fileimport_url(@fileimport)
    end

    assert_redirected_to fileimports_url
  end
end

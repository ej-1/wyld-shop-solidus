class ApplicationController < ActionController::Base

  protect_from_forgery with: :exception
  def after_sign_in_path_for(resource) # Custom method to meant to redirect user back to product page after login.
    request.env['omniauth.origin'] || stored_location_for(resource) || (params["current_url"].nil? == true) ? '/' : params["current_url"] # https://github.com/plataformatec/devise/wiki/How-To:-redirect-to-a-specific-page-on-successful-sign-in
    #binding.pry
  end
end


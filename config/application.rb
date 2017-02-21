require_relative 'boot'

require 'rails/all'
require 'csv' # For CSV, Excel file import.
require 'iconv' # For CSV, Excel file import.

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WyldShopSolidus
  class Application < Rails::Application
    config.assets.initialize_on_precompile = false
    config.assets.precompile += %w( all.scss )
    config.assets.paths << Rails.root.join("assets", "stylesheets", "spree", "frontend", "all")

    config.to_prepare do
      # Load application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Load application's view overrides
      Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end


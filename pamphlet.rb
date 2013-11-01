# ==========================================================================
#
# TODO
# ==========================================================================
#
# if devise is used, setup the user's fixtures and write model tests for the
# user model or whatever they name the model.
#
# * write fixtures for any models created
# * write unit tests for any models created
#
#
#

# ==========================================================================
# Add some directories
# ==========================================================================

## Application Objects
run "mkdir -p app/decorators"
run "mkdir -p app/presenters"

## Test Supporting Objects
run "mkdir -p test/matchers"
run "mkdir -p test/support"
run "mkdir -p test/assets"

## Script Directory
run "mkdir -p script"

## Directories for javascript templates and fonts
run "mkdir -p app/assets/templates"
run "mkdir -p app/assets/fonts"

## Make sure these directories get added to git
run "touch app/assets/templates/.gitkeep"
run "touch app/assets/fonts/.gitkeep"
run "touch test/assets/.gitkeep"
run "touch test/matchers/.gitkeep"
run "touch test/support/.gitkeep"

## Create env files for development
run "touch .env.dev"

# ==========================================================================
# Setup Gems
# ==========================================================================
@sequel     = yes?("Did you want to Sequel?")

@simpleform = yes?("Do you want to use simpleform?")
@devise     = yes?("Do you want to use devise for Authentication?")
@bourbon    = yes?("Do you want to use Bourbon & Neat for UI Structure?")
@angular    = yes?("Are you going to use Angular.js?")

@mysql      = !open('config/database.yml', 'r').grep(/mysql/).empty?
@sqlite     = !open('config/database.yml', 'r').grep(/sqlite3/).empty?
@postgres   = !open('config/database.yml', 'r').grep(/postgres/).empty?


unless @sqlite
  @username   = ask("What username will you be using for development and testing? (defaults to '`whoami`')")
  @password   = ask("What password will you be using for development and testing? (defaults to empty string)")
  @username   = "root"          if @mysql && @username.blank?
  @username ||= `whoami`.chomp  if @username.blank?
end

if @sequel
  gem('sequel_pg', require: 'sequel') if @postgres
  gem 'sequel' unless @postgres
end

if @simpleform
  gem 'simple_form', '~> 3.0.0'
  generate "simple_form:install"
end

if @devise
  gem 'devise', '~> 3.1.1'
  generate "devise:install"
  model_name = ask("What would you like the user model to be called? (defaults to 'user')")
  model_name = "user" if model_name.blank?
  generate "devise", model_name
end

if @bourbon
  gem 'bourbon'
  gem 'neat'
end

if @angular
  gem 'angularjs-rails'
end

gem 'unicorn'

gem_group :development, :test do
  gem 'pry'
  gem 'foreman'
end

gem_group :development do
  gem 'capistrano'
  gem 'metric_fu'
  gem 'cane'
  gem 'brakeman'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'meta_request'
end

gem_group :test do
  gem 'minitest',   require: false
  gem 'rack-test',  require: false
  gem 'mocha',      require: false
  gem 'simplecov'
  gem 'capybara'

  gem 'fixture_overlord', github: 'revans/fixture_overlord', branch: :master
end


#
# Performance turning and UML diagraming
# --------------------------------------
#
# these require graphviz ghostscript
#
# add to config/application.rb
# config.middleware.use ::Rack::PerftoolsProfiler, default_printer: 'gif', bundler: true
#
# view in browser
# ---------------
#
# http://localhost:3000/some_action?profile=true

# gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', group: :development

# generates model and controller UML diagrams as svg and dot
# gem 'railroady', group: :development

inject_into_file 'Gemfile', "\nruby '2.0.0'\n", after: "source 'https://rubygems.org'"


# ==========================================================================
# Run bundle install
# ==========================================================================
run "bundle install"


# ==========================================================================
# Create a Procfile
# ==========================================================================
run "echo 'web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb"

# We need this with foreman to see log output immediately
run <<-EOF
tee -a config/environments/development.rb <<EOTL

STDOUT.sync = true
EOTL
EOF

# ==========================================================================
# Add a .rbenv-vars files for use with rbenv,
# foreman, and pow
# ==========================================================================
run <<-EOF
tee .rbenv-vars <<EOTL
RACK_ENV=development
RAILS_ENV=development
PORT=7000
EOTL
EOF

# ==========================================================================
# Copy database yaml to an ERB file and edit it
# ==========================================================================

if !@mysql && !@sqlite
  inject_into_file 'config/database.yml', "\n  host: localhost\n", after: "password:" # need this for postgresql, not sure about mysql
end

run "cp config/database.yml config/database.yml.erb"

if !@sqlite
  gsub_file "config/database.yml", /username: .*/, "username: #{@username}"
  gsub_file "config/database.yml", /password: .*/, "password: #{@password}"

  gsub_file "config/database.yml.erb", /username: .*/,  "username: <%= @user %>"
  gsub_file "config/database.yml.erb", /password:/,     "password: pass"
  gsub_file "config/database.yml.erb", /password: .*/,  "password: <%= @password %>"
end

# ==========================================================================
# Replace ActiveRecord with Sequel
# ==========================================================================
if @sequel
  gsub_file "config/environments/development.rb", /config.active_record.migration_error = :page_load/, "# config.active_record.migration_error = :page_load"
  gsub_file "config/application.rb", /require 'rails\/all'/, "# require 'rails/all'"

  inject_into_file 'config/application.rb', after: "# require 'rails/all'\n" do <<-'RUBY'
# frameworks removed:
#
# * active_record
#

# require the frameworks we want:
#
%w(
  action_controller
  action_view
  action_mailer
  rails/test_unit
  sprockets
).each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
  end
end
    RUBY
  end

  application do <<-'RUBY'
config.generators do |g|
      g.orm :sequel
    end

  RUBY
  end
end

# ==========================================================================
# Add password_confirmation to be filtered from the logs
# ==========================================================================
gsub_file 'config/initializers/filter_parameter_logging.rb', /Rails.application.config.filter_parameters \+= \[:password\]/, 'Rails.application.config.filter_parameters += [:password, :password_confirmation]'

# ==========================================================================
# Setup Devise's layouts
# ==========================================================================
if @devise
  application do <<-'RUBY'

    config.to_prepare do
      Devise::SessionsController.layout       'login'
      Devise::RegistrationsController.layout  'login'
      Devise::ConfirmationsController.layout  'login'
      Devise::UnlocksController.layout        'login'
      Devise::PasswordsController.layout      'login'
    end
    RUBY
  end
end
# ==========================================================================
# Update the Git Ignore File
# ==========================================================================
run <<-ABC
tee -a .gitignore <<EOF
config/database.yml
.env
.DS_Store
coverage
.powenv

EOF
ABC

# ==========================================================================
# Create a .agignore file for use with
#   'The SilverSearcher' awk replacement
# ==========================================================================
run <<-EOF
tee .agignore <<EOTL
log
vender
script
doc
tmp
script
public
EOTL
EOF

# ==========================================================================
# Added a unicorn.rb file to config/
# ==========================================================================
run <<-OFE
tee config/unicorn.rb <<EOTL
# in general, 3 workers seems to be the best. Smaller apps can increase this
worker_processes 3

# Load the app into the master before forking workers for super-fast worker
# spawn times
preload_app true

# immediately restart any workers that haven't responded within 30 seconds
timeout 30

# queue_classic PID
# @qc_pid = nil

before_fork do |server, worker|
  # @qc_pid ||= spawn( "bundle exec rake qc:work" )
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end

after_fork do |server, worker|
  # @qc_pid ||= spawn( "bundle exec rake qc:work" )
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end
EOTL
OFE

# ==========================================================================
# Add a Simplecov Config File
# ==========================================================================
run <<-EOF
tee test/simplecov_config.rb <<EOTL
require 'simplecov'
module SimplecovConfig
  ::SimpleCov.use_merging true
  ::SimpleCov.start 'rails' do

    # filters
    add_filter 'lib/tasks'

    # groups
    add_group 'Controllers',    'app/controllers'
    add_group 'Models',         'app/models'
    add_group 'Decorators',     'app/decorators'
    add_group 'Presenters',     'app/presenters'
    add_group 'Helpers',        'app/helpers'
    add_group 'Mailers',        'app/mailers'
    add_group 'Libraries',      'lib'

    ## Additional Objects that could be added to your Rails Application
    #
    # add_group 'Services',       'app/services'
    # add_group 'Forms',          'app/forms'
    # add_group 'ViewObjects',    'app/view_objects'
    # add_group 'QueryObjects',   'app/query_objects'
    # add_group 'PolicyObjects',  'app/policy_objects'
    # add_group 'ValueObjects',   'app/value_objects'

    merge_timeout 3600
  end
end
EOTL
EOF


# ==========================================================================
# Update the test helper to use some specific settings
# ==========================================================================
gsub_file 'test/test_helper.rb', /fixtures :all/, '# fixtures :all'

inject_into_file 'test/test_helper.rb', :after => "require 'rails/test_help'\n" do <<-'RUBY'
require 'capybara/dsl'
require 'minitest/autorun'
require 'fixture_overlord'

if ENV['COVERAGE']
  require_relative 'simplecov_config'
  include SimplecovConfig
end

silence_warnings { require 'mocha/setup' }
Dir[Rails.root.join('test/support/**/*.rb')].each { |file| require file }

# load our custom matchers
Dir[Rails.root.join('test/matchers/**/*.rb')].each { |file| require file }

# setup Capybara
# Capybara.app = ApplicationName::Application
Capybara.default_driver = :rack_test

RUBY
end

inject_into_file 'test/test_helper.rb', :after => "ActiveRecord::Migration.check_pending!\n" do <<-'RUBY'
  include ::FileHelper
  include ::FixtureOverlord

  fixture_overlord :rule
RUBY
end

run <<-EOF
tee -a test/test_helper.rb <<EOTL

############################
class ActionController::TestCase
  include ::FileHelper
  include ::FixtureOverlord
  fixture_overlord :rule

  self.use_transactional_fixtures = true
end

############################
class ActionDispatch::IntegrationTest
  include ::FileHelper
  include ::FixtureOverlord
  fixture_overlord :rule

  self.use_transactional_fixtures = true
  include Capybara::DSL

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end

############################
class ActionView::TestCase
  include ::FileHelper
  include ::FixtureOverlord
  fixture_overlord :rule
end

##############################################
# Spec-ing setup
class MiniTest::Spec
  include Rails.application.routes.url_helpers
  include ActiveSupport::Testing::SetupAndTeardown
  include ActiveRecord::TestFixtures

  Rails.application.routes.default_url_options[:host] = 'example.com'

  alias :method_name :__name__ if defined?(:__name__)
  self.fixture_path = File.join( Rails.root, 'test', 'fixtures' )

  include ::FileHelper
  include ::FixtureOverlord
  fixture_overlord :rule

  class << self
    alias :context :describe
  end

  before do
    @routes = Rails.application.routes
  end
end

class ControllerSpec < MiniTest::Spec
  include ActionController::TestCase::Behavior
end

# Controller Unit test = describe ***Controller
MiniTest::Spec.register_spec_type(/Controller$/, ControllerSpec)

class AcceptanceSpec < MiniTest::Spec
  include Capybara::DSL

  after do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end

# Acceptance tests = describe "Feature:..."
MiniTest::Spec.register_spec_type(/^Feature:/i, AcceptanceSpec)

EOTL
EOF

# ==========================================================================
# Add file helpers for tests
# ==========================================================================
run <<-EOF
tee test/support/file_helpers.rb <<EOTL
require 'pathname'

module FileHelper
  def asset_path
    Rails.root.join('test/assets')
  end

  def read_file(filename)
    asset_path.join(filename).read
  end

  def open_file(filename)
    asset_path.join(filename).to_s
  end

  def write_fixture_file(filename, content)
    ::File.open(asset_path.join(filename), 'w+') { |f| f.puts content.to_json }
  end

  def fixture_data(name)
    YAML.dump(asset_path.join(name).read)
  end
end
EOTL
EOF

# Add file helper to test_helper.rb class

# ==========================================================================
# Adding Cane Rake Task
# ==========================================================================
rakefile "cane.rake" do <<-'RUBY'
unless Rails.env.production?
  begin
    require 'cane/rake_task'

    desc "Run cane to check quality metrics"
    Cane::RakeTask.new(:quality) do |cane|
      cane.abc_max = 10
      cane.add_threshold 'coverage/covered_percent', :>=, 99
      cane.no_style = false
      cane.abc_exclude = %w(Foo::Bar#some_method)
    end

    task :default => :quality
  rescue LoadError
    warn "cane not available, quality task not provided."
  end
end
  RUBY
end

# ==========================================================================
# Adding Fixture Generator Tasks
# ==========================================================================
rakefile "fixtures.rake" do <<-'RUBY'
require 'yaml'
require 'active_support'

# include ActionView::Helpers::TextHelper

namespace :fixtures do
  desc "Write fixture data files from seed data within the database"
  task :write => :environment do

    # fixture directory to write to
    fixture_directory = Dir.glob(Rails.root.join("{spec,test}/fixtures")).first

    # read all files from the app/models, strip them of their path and
    # extension, convert each basename to a Model Class
    models = Dir.glob(Rails.root.join("app/models/**/*.rb")).
              map { |model| File.basename(model, ".rb").camelize.constantize }

    # iterate over all models and write each of their data to a fixture file
    models.each do |model|

      # only process models that inherit from ActiveRecord::Base
      next unless model.respond_to?(:superclass) && model.superclass == ActiveRecord::Base

      # Open a File with the model name within the fixtures location (path)
      File.open(File.join(fixture_directory, model.to_s.pluralize + "_fixture.yml"), "w") do |file|

        # iterate over the model data and dump it as yaml to the fixture file
        model.all.each { |klass| YAML.dump(klass, file) }

      end

    end
  end
end
  RUBY
end

# ==========================================================================
# Adding Generate Database conf
# ==========================================================================
rakefile "generate_database_conf.rake" do <<-'RUBY'
require 'erb'
namespace :db do
  namespace :config do

    desc "Generate a config/database.conf"
    task :create do
      db_example  = Rails.root.join("config/database.yml.erb")
      puts
      puts  "Creating a new config/database.yml file. I'm going to need some information."
      puts
      print "What is your username for your local database? (leave empty to use #{`whoami`.chomp}): "
      %x{stty -icanon -echo}
      @user = STDIN.gets.chomp

      puts
      print "What is your password for your local database? (leave empty for no password): "

      %x{stty -icanon -echo}
      @password = STDIN.gets.chomp

      @user = %x|whoami|.chomp if @user.blank?

      content = ERB.new(db_example.read).result
      File.open(Rails.root.join("config/database.yml").to_s, "w") do |file|
        file.write content
      end
    end

    desc "Create a config/database.conf for Jenkins"
    task :jenkins, :user, :password do |_, args|
      db_example  = Rails.root.join("config/database.yml.erb")

      # get data
      @user     = args[:user]
      @password = args[:password]

      content = ERB.new(db_example.read).result
      File.open(Rails.root.join("config/database.yml").to_s, "w") do |file|
        file.write content
      end
    end

  end
end
  RUBY
end

# ==========================================================================
# Rebuild the Database Rake Task
# ==========================================================================
rakefile "rebuild.rake" do <<-'RUBY'
namespace :db do
  desc 'Rebuild the database'
  task :rebuild => :environment do
    steps = Rails.root.join("db/migrate").children.size

    %w(db:drop db:create db:schema:load db:seed db:test:prepare).each do |task|
      Rake::Task[task].invoke
    end
  end
end
  RUBY
end

# ==========================================================================
# Report Generator Rake Task
# ==========================================================================
rakefile "reports.rake" do <<-'RUBY'
unless Rails.env.production?
  namespace :report do
    desc "Run SimpleCov"
    task :coverage do
      require 'simplecov'
      SimpleCov.start 'rails'
      Rake::Task["test"].execute
    end

    desc "Run Cane"
    task :cane do
      Rake::Task["quality"].invoke
    end

    desc "Run MetricFu"
    task :metrics do
      system('cd ' + Rails.root.to_s + ' metric_fu -r')
    end

    desc "Run Brakeman"
    task :security do
      system 'cd ' + Rails.root.to_s + ' brakeman -d -o tmp/security.html'
    end

    desc "Run all Reports"
    task :all do
      Rake::Task['report:coverage'].invoke
      Rake::Task['report:metrics'].invoke
      Rake::Task['report:security'].invoke
      Rake::Task['report:cane'].invoke
    end
  end
end
  RUBY
end

# ==========================================================================
# Rake tasks for various types of tests
# ==========================================================================
rakefile "test.rake" do <<-'RUBY'
namespace :test do
  desc "Acceptance tests"
  Rake::TestTask.new(:acceptance) do |t|
    t.libs << "test"
    t.pattern = "test/acceptance/**/*_test.rb"
    t.verbose = true
  end

  desc "Service tests"
  Rake::TestTask.new(:services) do |t|
    t.libs << "test"
    t.pattern = "test/services/**/*_test.rb"
    t.verbose = true
  end

  desc "Library tests"
  Rake::TestTask.new(:libraries) do |t|
    t.libs << "test"
    t.pattern = "test/lib/**/*_test.rb"
    t.verbose = true
  end

  desc "Feature tests"
  Rake::TestTask.new(:features) do |t|
    t.libs << "test"
    t.pattern = "test/features/**/*_test.rb"
    t.verbose = true
  end

  desc "Resource tests"
  Rake::TestTask.new(:resources) do |t|
    t.libs << "test"
    t.pattern = "test/resources/**/*_test.rb"
    t.verbose = true
  end

  desc "Run with SimpleCov"
  Rake::TestTask.new(:coverage) do |t|
    require 'simplecov'
    SimpleCov.start 'rails'
    t.libs << "test"
    t.pattern = "text/**/**/*_test.rb"
    t.verbose = true
  end
end


Rake::Task[:test].enhance do
  Rake::Task["test:acceptance"].invoke
  Rake::Task["test:services"].invoke
  Rake::Task["test:libraries"].invoke
  Rake::Task["test:features"].invoke
  Rake::Task["test:resources"].invoke
end
  RUBY
end

# ==========================================================================
# Rake Task to create a new Secret Token and store it in the .env file
# ==========================================================================
rakefile "secret.rake" do <<-'RUBY'
namespace :secret do
  desc "Write a new Secret Token to the .env file"
  task :token => :environment do
    system <<-RAKE
      rake secret | head -n1 | awk '{ print "session_token: " $1 }' > .env
    RAKE
  end
end
  RUBY
end

# ==========================================================================
# Add Private Api Constraints
# ==========================================================================
lib "private_api_constraints.rb" do <<-'RUBY'
# Example of how to use within the config/routes.rb file
# namespace :api, defaults: { format: 'json' } do
#   scope module: :v1, constraints: PrivateApiConstraints.new(version: 1, default: true) do
#     ....
#   end
# end

class PrivateApiConstraints
  def initialize(options)
    @version = options[:version]
    @default = options[:default]
  end

  # TODO: Change the 'vendor' to the company name
  #       and change 'application_name' to the actual application name
  def matches?(req)
    @default || req.headers['Accept'].include?("application/vnd.vendor.application_name-v#{@version}+json")
  end
end
  RUBY
end

# ==========================================================================
# Add Font Mime Types
# ==========================================================================
run <<-EOF
tee -a config/initializers/mime_types.rb <<EOTL

# Register WOFF mime type with Rack
# rack/sprockets fail on this
Rack::Mime::MIME_TYPES['.woff'] = 'application/x-font-woff'

# Register mime types for web fonts
# Mime::Type.register "font/opentype",                  :otf
# Mime::Type.register "application/x-font-woff",        :woff
# Mime::Type.register "application/x-font-ttf",         :ttf
# Mime::Type.register "application/vnd.ms-fontobject",  :eot
# Mime::Type.register "image/svg+xml",                  :svg
EOTL
EOF

# ==========================================================================
# Asset Sync-ing
# ==========================================================================
initializer "asset_sync.rb" do <<-'RUBY'
  # if defined?(AssetSync) && Rails.env.production?
  #   AssetSync.configure do |config|

  #     # fog setup
  #     config.fog_provider           = ENV['FOG_PROVIDER']
  #     config.fog_directory          = ENV['FOG_DIRECTORY']
  #     config.fog_region             = ENV['FOG_REGION']

  #     # These can be found under Access Keys in AWS Security Credentials
  #     config.aws_access_key_id      = ENV['AWS_ACCESS_KEY_ID']
  #     config.aws_secret_access_key  = ENV['AWS_SECRET_ACCESS_KEY']


  #     # don't delete files from the store
  #     config.existing_remote_files = 'keep'

  #     # automatically replace files with their equaivalent gzip compressed version
  #     config.gzip_compression = true
  #   end
  # end
  RUBY
end

# ==========================================================================
# Add new flash types and a respond_to :html, :js, :json
# ==========================================================================
inject_into_file 'app/controllers/application_controller.rb', after: "protect_from_forgery with: :exception\n" do <<-'RUBY'

  # adds more flash types
  add_flash_types :error, :success, :info, :block
  respond_to :html, :js, :json
RUBY
end

# ==========================================================================
# Rename the CSS and JS files to SCSS and Coffee
# ==========================================================================
run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"
run "mv app/assets/javascripts/application.js app/assets/javascripts/application.js.coffee"
run "sed -i '' /require_tree/d app/assets/stylesheets/application.css.scss"

if @bourbon
  run "echo >> app/assets/stylesheets/application.css.scss"
  run "echo '@import \"bourbon\";' >>  app/assets/stylesheets/application.css.scss"
  run "echo '@import \"neat\";' >>  app/assets/stylesheets/application.css.scss"
end

run "echo '#= require jquery\n#= require jquery_ujs\n#= require turbolinks\n#= require_tree .' > app/assets/javascripts/application.js.coffee"

# ==========================================================================
# Add a module to be extended to override the inheritance type column in
# rails.
# ==========================================================================
run <<-EOF
tee app/models/override_inheritance_type.rb <<EOTL
# Overrides Rails typical type inheritance
#
# e.g.  to overide the type inheritance column,
#       in your model add:
#
#    extend OverrideTypeInheritance
#
module OverrideTypeInheritance
  def inheritance_column
    "override its black magic"
  end
end
EOTL
EOF

# ==========================================================================
# Add a base decorator class that can be used to build custom decorators
# ==========================================================================
run <<-EOF
tee app/decorators/decorate.rb <<EOTL
require 'delegate'

# Decorators are for sprinkling methods on model objects for use within Service type objects
module Decorators
  # Decorator is an inheritable class object to DRY necessary methods
  class Decorate < SimpleDelegator

    # Model: pass the constructor the model object
    def initialize(model)
      super(model)
    end

    # delegates method calls off to the actual model object
    def to_model
      __getobj__
    end

    # delegates the class method call to the model object
    def class
      to_model.class
    end
  end
end

EOTL
EOF

# ==========================================================================
# Add a base presenter class that can be used to build custom presenters
# ==========================================================================
run <<-EOF
tee app/presenters/presenter.rb <<EOTL
require 'delegate'

# Presenters sprinkle methods on model objects, service objects, or decorators objects specifically
# for presenting to the view.
module Presenters
  class Presenter < SimpleDelegator

    # Model: The model, service, decorator object
    # Template: the specific view that the presenter will be used within
    def initialize(model, template)
      @template = template
      super(model)
    end

    # delegates to the model/service/decorator object so their internal methods can
    # be used
    def to_model
      __getobj__
    end

    # delegates to the model/service/decorator object class name
    def class
      to_model.class
    end

    # alias method for the template object
    def h
      @template
    end
  end
end

EOTL
EOF


# ==========================================================================
# Add a setup script to setup the application
# ==========================================================================
run <<-EOF
tee script/setup <<EOTL
#!/usr/bin/env bash
set -e

# install gems
./bin/bundle

# create config/database.yml file
./bin/rake db:config:create --trace

# create database(s)
./bin/rake db:create --trace

# migrate those databases
./bin/rake db:migrate --trace

# input seed data into the database
./bin/rake db:seed --trace

echo
echo
# Instructions
echo "==> Dependencies (gems) have been installed."
echo "==> Database connection adapter(config/database.yml) has been created."
echo "==> The database has been migrated to the latest Schema."
echo "==> Seed data has been loaded into the database."
echo
echo "==> Type 'powder -h' at the terminal to see commands for the Pow Server."
echo "==> Type 'rake -T' at the terminal to see commands available for Rake to run against the Rails application."
echo
echo "==> Setting up the Pow Server. It'll output a URL you can use within the browser to interact with this application."


# setup pow
powder link

EOTL
EOF
run "chmod +x script/setup"

# ==========================================================================
# Add a jenkins script for CI setup
# ==========================================================================
run <<-EOF
tee script/jenkins <<EOTL
#!/usr/bin/env bash

set -e

# install gems
./bin/bundle

# create config/database.yml file
./bin/rake db:config:jenkins[jenkins,jankyjenkins] --trace

./bin/rake db:rebuild --trace

# create database(s)
# ./bin/rake db:create --trace

# migrate those databases
# ./bin/rake db:migrate --trace

# build test database from the schema
./bin/rake db:test:prepare --trace

# run all tests
./bin/rake test

EOTL
EOF
run "chmod +x script/jenkins"

# ==========================================================================
# Update the default layout
# ==========================================================================
run <<-EOF
tee app/views/layouts/application.html.erb <<EOTL
<!DOCTYPE html>
<!--[if lt IE 7]>       <html class="no-js lt-ie9 lt-ie8 lt-ie7"> <![endif]-->
<!--[if IE 7]>          <html class="no-js lt-ie9 lt-ie8"> <![endif]-->
<!--[if IE 8]>          <html class="no-js lt-ie9"> <![endif]-->
<!--[if IEMobile 7 ]>   <html class="no-js iem7"> <![endif]-->

<!--[if (gt IE 8)|(gt IEMobile 7)|!(IEMobile)]><!-->
<html class="no-js">
<!--<![endif]-->


<head>
  <meta charset="utf-8">
  <meta name="description" content="">

  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta http-equiv="cleartype" content="on">
  <meta name="HandheldFriendly" content="True">
  <meta name="MobileOptimized" content="320">
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <link rel="apple-touch-icon-precomposed" sizes="144x144" href="img/touch/apple-touch-icon-144x144-precomposed.png">
  <link rel="apple-touch-icon-precomposed" sizes="114x114" href="img/touch/apple-touch-icon-114x114-precomposed.png">
  <link rel="apple-touch-icon-precomposed" sizes="72x72" href="img/touch/apple-touch-icon-72x72-precomposed.png">
  <link rel="apple-touch-icon-precomposed" href="img/touch/apple-touch-icon-57x57-precomposed.png">
  <link rel="shortcut icon" href="img/touch/apple-touch-icon.png">

  <!-- Tile icon for Win8 (144x144 + tile color) -->
  <meta name="msapplication-TileImage" content="img/touch/apple-touch-icon-144x144-precomposed.png">
  <meta name="msapplication-TileColor" content="#222222">


  <!-- For iOS web apps. Delete if not needed. https://github.com/h5bp/mobile-boilerplate/issues/94 -->
    <!--
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <meta name="apple-mobile-web-app-title" content="">
    -->

  <!-- This script prevents links from opening in Mobile Safari. https://gist.github.com/1042026 -->
    <!--
    <script>(function(a,b,c){if(c in b&&b[c]){var d,e=a.location,f=/^(a|html)$/i;a.addEventListener("click",function(a){d=a.target;while(!f.test(d.nodeName))d=d.parentNode;"href"in d&&(d.href.indexOf("http")||~d.href.indexOf(e.host))&&(a.preventDefault(),e.href=d.href)},!1)}})(document,window.navigator,"standalone")</script>
    -->

    <title></title>

    <%= stylesheet_link_tag    "application", media: "all", "data-turbolinks-track" => true %>
    <%= javascript_include_tag "application", "data-turbolinks-track" => true %>
    <%= csrf_meta_tags %>

  </head>
  <body ng-app>
    <!--[if lt IE 7]>
      <p class="chromeframe">You are using an <strong>outdated</strong> browser. Please <a href="http://browsehappy.com/">upgrade your browser</a> or <a href="http://www.google.com/chromeframe/?redirect=true">activate Google Chrome Frame</a> to improve your experience.</p>
    <![endif]-->

    <div class="container">
      <div class="row">
        <div class="col-md-3"></div>
        <div class="col-md-9" role="main">
          <%= yield %>
        </div>
      </div>
    </div>

  </body>
</html>
EOTL
EOF

# ==========================================================================
# Add bootstrap
# ==========================================================================
run <<-EOF
curl https://raw.github.com/twbs/bootstrap/master/dist/css/bootstrap.min.css > vendor/assets/stylesheets/bootstrap.css
curl https://raw.github.com/twbs/bootstrap/master/dist/js/bootstrap.min.js > vendor/assets/javascripts/bootstrap.js
EOF

# ==========================================================================
# Add Bootstrap to the 'Assets to be Precompiled' list
# ==========================================================================
run <<-EOF
tee config/environments/assets_to_precompile.rb <<EOTL
# Assets to Precompile
#
# Use a module to manage the assets that are added and need to be precompiled
# so we don't have to add them to each environment.
#
module AssetsToPrecompile
  extend self

  # JavaScript and CSS Assets
  def list
    stylesheets + javascripts
  end

  def javascripts
    %w|bootstrap.js|
  end

  def stylesheets
    %w|bootstrap.css|
  end
end
EOTL
EOF

gsub_file "config/environments/production.rb", /# config.assets.precompile \+= %w\( search\.js \)/, "require_relative 'assets_to_precompile'\n  config.assets.precompile += AssetsToPrecompile.list"



# ==========================================================================
# Move the Readme to Markdown
# ========================================================================
run "rm README.rdoc"
run "echo '# Readme' > Readme.mkd"


# ==========================================================================
# Move the Secret Token to use ENV
# ========================================================================
#
# This needs to run after bundler has ran
#
gsub_file "config/initializers/secret_token.rb", /= '\w+'/, "= ENV['secret_token']"
run <<-EOF
rake secret | head -n1 | awk '{ print "session_token: " $1 }' > .env
EOF


# ==========================================================================
# Create database, Run migrations, and get this into version control
# ==========================================================================
rake "db:create"
rake "db:migrate"

run <<-EOF
git init
git add --all
git commit -am "Stubbed out the Application"
EOF

puts "To get the Twitter Bootstrap Font files, you can go here: https://github.com/twbs/bootstrap/tree/master/dist/fonts"
puts "Don't forget Modernizr: http://modernizr.com/download/"
puts "We didn't add it because we haven't found an easy way to automate the latest build to download."

# ==========================================================================
#
# ==========================================================================

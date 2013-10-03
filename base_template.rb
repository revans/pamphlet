# ==========================================================================
# Add some directories
# ==========================================================================
run "mkdir -p test/matchers"
run "mkdir -p test/support"
run "mkdir -p app/decorators"
run "mkdir -p app/presenters"
run "mkdir -p script/setup"
run "mkdir -p script/jenkins"

# ==========================================================================
# Setup Gems
# ==========================================================================

gem 'simple_form' if yes?("Use simpleform?")

@bourbon = yes?("Bourbon & Neat for UI Structure?")
if @bourbon
  gem "bourbon"
  gem "neat"
end


gem 'debugger',   group: [:development, :test]
gem 'pry',        group: [:development, :test]
gem 'foreman',    group: [:development, :test]



gem 'capistrano',         group: :development
gem 'metric_fu',          group: :development
gem 'cane',               group: :development
gem 'brakeman',           group: :development
gem 'better_errors',      group: :development
gem 'binding_of_caller',  group: :development
gem 'meta_request',       group: :development

gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', group: :development

# generates model and controller UML diagrams as svg and dot
gem 'railroady', group: :development

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


gem 'minitest',   require: false,   group: :test
gem 'rack-test',  require: false,   group: :test
gem 'mocha',      require: false,   group: :test
gem 'simplecov',                    group: :test
gem 'capybara',                     group: :test

gem 'fixture_overlord', github: 'revans/fixture_overlord', group: :test

# ==========================================================================
# Create a Procfile
# ==========================================================================
run "echo 'web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb"

# We need this with foreman to see log output immediately
run "echo 'STDOUT.sync = true' >> config/environments/development.rb"

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
run "cp config/database.yml config/database.yml.erb"

# replace username: ... with: username: <%= @user %>
# replace password: ... with: password: <%= @password %>
run "sed -i 'username: <%= @user %>' /username:\s+\w+/g config/database.yml.erb"
run "sed -i 'password: <%= @password %>' /password:\s+\w+/g config/database.yml.erb"

# ==========================================================================
# Update the Git Ignore File
# ==========================================================================
run <<-ABC
tee -a .gitignore <<EOF
config/database.yml
.env
.DS_Store
converage
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
    # add_group 'Services',       'app/services'
    add_group 'Helpers',        'app/helpers'
    add_group 'Mailers',        'app/mailers'
    add_group 'Libraries',      'lib'

    merge_timeout 3600
  end
end
EOTL
EOF


# ==========================================================================
# Update the test helper to use some specific settings
# ==========================================================================
run <<-EOF
tee -a test/test_helper.rb <<EOTL

require 'capybara/dsl'
require 'minitest/autorun'

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

############################
class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!
  include FixtureOverlord

  fixture_overlord :rule

  def teardown
    # QC.delete_all
  end
end

############################
class ActionController::TestCase
  include FixtureOverlord
  fixture_overlord :rule

  self.use_transactional_fixtures = true

  def teardown
    # QC.delete_all
  end
end

############################
class ActionDispatch::IntegrationTest
  include FixtureOverlord
  fixture_overlord :rule

  self.use_transactional_fixtures = true
  include Capybara::DSL

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
    # QC.delete_all
  end
end

############################
class ActionView::TestCase
  include FixtureOverlord
  fixture_overlord :rule

  def teardown
    # QC.delete_all
  end
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

  include FixtureOverlord
  fixture_overlord :rule

  class << self
    alias :context :describe
  end

  before do
    @routes = Rails.application.routes
  end

  after do
    # QC.delete_all
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
# Add some test matcher assertions
# ==========================================================================
run <<-EOF
tee test/matchers/assertion_matchers.rb <<EOTL
require 'minitest/autorun'
module MiniTest::Assertions
  def assert_link(obj, msg = nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to be a link." }

    assert_includes obj, "<a",    msg
    assert_includes obj, "</a>",  msg
    assert_includes obj, "href=", msg
  end

  def refute_link(obj, msg = nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to not be a link." }

    refute_includes obj, "<a",    msg
    refute_includes obj, "</a>",  msg
    refute_includes obj, "href=", msg
  end

  def assert_remote_link(obj, msg=nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to be a remote link." }
    assert_link(obj)
    assert_includes obj, 'data-remote="true"'
  end

  def refute_remote_link(obj, msg=nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to not be a remote link." }

    refute_link(obj, msg)
    refute_includes obj, 'data-remote="true"', msg
  end

  def assert_link_to(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} to be a link to #{mu_pp(exp)}."
    }

    assert_includes act, exp, msg
  end

  def refute_link_to(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} to not be a link to #{mu_pp(exp)}."
    }

    refute_includes act, exp, msg
  end

  def assert_icon_for(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} class attribute to be set to icon-#{mu_pp(exp)}."
    }

    assert_includes act, "icon-#{exp}", msg
  end

  def refute_icon(obj, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} class attribute to not be set to icon-#{mu_pp(exp)}."
    }

    refute_includes act, "icon-#{exp}", msg
  end
end

# String.infect_an_assertion :assert_link, :must_be_link
# String.infect_an_assertion :assert_remote_link, :must_be_remote_link
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

  def fixture_data(name)
    YAML.dump(asset_path.join(name).read)
  end
end
EOTL
EOF

# ==========================================================================
# Adding Cane Rake Task
# ==========================================================================
run <<-EOF
tee lib/tasks/cane.task <<EOTL
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
EOTL
EOF

# ==========================================================================
# Adding Fixture Generator Tasks
# ==========================================================================
run <<-EOF
tee lib/tasks/fixtures.rake <<EOTL
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
      File.open(File.join(fixture_directory, "#{model.to_s.pluralize}_fixture.yml"), "w") do |file|

        # iterate over the model data and dump it as yaml to the fixture file
        model.all.each { |klass| YAML.dump(klass, file) }

      end

    end
  end
end

EOTL
EOF

# ==========================================================================
# Adding Generate Database conf
# ==========================================================================
run <<-EOF
tee lib/tasks/generate_database_conf.rake <<EOTL
require 'erb'
namespace :db do
  namespace :config do

    desc "Generate a config/database.conf"
    task :create do
      db_example  = Rails.root.join("config/database.yml.erb")
      puts
      puts  "Creating a new config/database.yml file. I'm going to need some information."
      print "What is your password for your local database? (leave empty for no password): "

      %x{stty -icanon -echo}
      # get data
      @user = `whoami`.chomp
      @password = STDIN.gets.chomp

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
EOTL
EOF

# ==========================================================================
# Rebuild the Database Rake Task
# ==========================================================================
run <<-EOF
tee lib/tasks/rebuild.rake <<EOTL
namespace :db do
  desc 'Rebuild the database'
  task :rebuild => :environment do
    steps = Rails.root.join("db/migrate").children.size

    %w(db:drop db:create db:schema:load db:seed db:test:prepare).each do |task|
      Rake::Task[task].invoke
    end
  end
end
EOTL
EOF

# ==========================================================================
# Report Generator Rake Task
# ==========================================================================
run <<-EOF
tee lib/tasks/reports.rake <<EOTL
unless Rails.env.production?
  namespace :report do
    desc "Run SimpleCov"
    task :coverage do
      `COVERAGE=true rake test`
    end

    desc "Run Cane"
    task :cane do
      Rake::Task["quality"].invoke
    end

    desc "Run MetricFu"
    task :metrics do
      `cd #{Rails.root.to_s} && metric_fu -r`
    end

    desc "Run Brakeman"
    task :security do
      `cd #{Rails.root.to_s} && brakeman -d -o tmp/security.html`
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
EOTL
EOF

# ==========================================================================
# Rake tasks for various types of tests
# ==========================================================================
run <<-EOF
tee lib/tasks/test.rake <<EOTL

# expand to the "extra" tests that we have
# feature_tests   = Rake::Task["test:acceptance"]
# service_tests   = Rake::Task["test:services"]
library_tests   = Rake::Task["test:libraries"]
feature_tests   = Rake::Task["test:features"]
resource_tests  = Rake::Task["test:resources"]

test_task = Rake::Task[:test]
test_task.enhance do
  # feature_tests.invoke
  # service_tests.invoke
  library_tests.invoke
  feature_tests.invoke
  resource_tests.invoke
end

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
end
EOTL
EOF

# ==========================================================================
# Add Private Api Constraints
# ==========================================================================
run <<-EOF
tee lib/private_api_constraints.rb <<EOTL

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
EOTL
EOF

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
run <<-EOF
tee -a config/initializers/asset_sync.rb <<EOTL

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

EOTL
EOF

# ==========================================================================
# Add new flash types and a respond_to :html, :js, :json
# ==========================================================================
run <<-EOF
tee -a app/controller/application_controller.rb <<EOTL

# adds more flash types
add_flash_types :error, :success, :info, :block
respond_to :html, :js, :json

EOTL
EOF

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
#
# ==========================================================================
# ==========================================================================
#
# ==========================================================================
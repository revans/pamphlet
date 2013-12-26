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
# See what database was selected
# ==========================================================================
@mysql      = !open('config/database.yml', 'r').grep(/mysql/).empty?
@sqlite     = !open('config/database.yml', 'r').grep(/sqlite3/).empty?
@postgres   = !open('config/database.yml', 'r').grep(/postgres/).empty?

# ==========================================================================
# Get the current users' username
# ==========================================================================
@username   = "root"            if @mysql && @username.blank?
@username ||= ::ENV['USER']     if @username.blank?

# ==========================================================================
# Add some directories
# ==========================================================================

directories = %w|app/assets/templates
                 app/assets/fonts
                 app/domain_objects/decorators
                 app/domain_objects/value_objects
                 app/domain_objects/service_objects
                 app/domain_objects/form_objects
                 app/domain_objects/query_objects
                 app/domain_objects/view_objects
                 app/domain_objects/policy_objects
                 test/domain_objects/decorators
                 test/domain_objects/value_objects
                 test/domain_objects/service_objects
                 test/domain_objects/form_objects
                 test/domain_objects/query_objects
                 test/domain_objects/view_objects
                 test/domain_objects/policy_objects
                 test/matchers
                 test/support
                 test/assets
                |

# Create new directories
directories.each { |dir| run "mkdir -p #{dir}" }

# Add a .gitkeep to each new directory so they are committed to git
directories.each { |dir| run "touch #{dir}/.gitkeep" }

# ==========================================================================
# Setup Gems
# ==========================================================================
gem 'angularjs-rails'
gem 'virtus'
gem 'puma'
gem 'rack-timeout'

gem_group :staging, :production do
  gem 'rails_12factor'
end

gem_group :development, :test do
  gem 'pry'
  gem 'foreman'
end

gem_group :development do
  gem 'turbulence'
  gem 'metric_fu'
  gem 'cane'
  gem 'brakeman'
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
# run "echo 'web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb"
run "echo 'web: bundle exec puma -p $PORT -c ./config/puma.rb"

# We need this with foreman to see log output immediately
prepend_file "config/environments/development.rb", "STDOUT.sync = true\n\n"

# ==========================================================================
# Add a .env.dev files for use with rbenv,
# foreman, and pow
# ==========================================================================
run <<-EOF
tee .env.dev <<EOTL
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
  # gsub_file "config/database.yml", /password: .*/, "password: #{@password}"

  gsub_file "config/database.yml.erb", /username: .*/,  "username: <%= @user %>"
  gsub_file "config/database.yml.erb", /password:/,     "password: pass"
  gsub_file "config/database.yml.erb", /password: .*/,  "password: <%= @password %>"
end


# ==========================================================================
# Add password_confirmation to be filtered from the logs
# ==========================================================================
gsub_file 'config/initializers/filter_parameter_logging.rb', /Rails.application.config.filter_parameters \+= \[:password\]/, 'Rails.application.config.filter_parameters += [:password, :password_confirmation]'


# ==========================================================================
# Update the Git Ignore File
# ==========================================================================
run <<-ABC
tee -a .gitignore <<EOF
.env
.foreman
.DS_Store
coverage
turbulence
config/puma.rb
config/database.yml
config/secrets.yml
EOF
ABC

# ==========================================================================
# Create a .agignore file for use with
#   'The SilverSearcher' awk replacement
# ==========================================================================
run <<-EOF
tee .agignore <<EOTL
Rakefile
Gemfile
config.ru
.git
.gitignore
.foreman
.env.dev
.env
vendor
tmp
test
public
log
db
config
bin
script
EOTL
EOF

# ==========================================================================
# Added a puma.rb file to config/
# ==========================================================================
run <<-OFE
tee config/puma.rb <<EOTL
#!/usr/bin/env puma

# The directory to operate out of.
#
# The default is the current directory.
#
# directory '/u/apps/lolcat'

# Use an object or block as the rack application. This allows the
# config file to be the application itself.
#
# app do |env|
#   puts env
#
#   body = 'Hello, World!'
#
#   [200, { 'Content-Type' => 'text/plain', 'Content-Length' => body.length.to_s }, [body]]
# end

# Load “path” as a rackup file.
#
# The default is “config.ru”.
#
# rackup '/u/apps/lolcat/config.ru'

# Set the environment in which the rack's app will run. The value must be a string.
#
# The default is “development”.
#
# environment 'production'
environment 'development'

# Daemonize the server into the background. Highly suggest that
# this be combined with “pidfile” and “stdout_redirect”.
#
# The default is “false”.
#
# daemonize
# daemonize false

# Store the pid of the server in the file at “path”.
#
# pidfile '/u/apps/lolcat/tmp/pids/puma.pid'

# Use “path” as the file to store the server info state. This is
# used by “pumactl” to query and control the server.
#
# state_path '/u/apps/lolcat/tmp/pids/puma.state'

# Redirect STDOUT and STDERR to files specified. The 3rd parameter
# (“append”) specifies whether the output is appended, the default is
# “false”.
#
# stdout_redirect '/u/apps/lolcat/log/stdout', '/u/apps/lolcat/log/stderr'
# stdout_redirect '/u/apps/lolcat/log/stdout', '/u/apps/lolcat/log/stderr', true

stdout_redirect '/u/apps/lolcat/log/stdout.log', '/u/apps/lolcat/log/stderr.log', true

# Disable request logging.
#
# The default is “false”.
#
# quiet

# Configure “min” to be the minimum number of threads to use to answer
# requests and “max” the maximum.
#
# The default is “0, 16”.
#
# threads 0, 16
threads 1, 16

# Bind the server to “url”. “tcp://”, “unix://” and “ssl://” are the only
# accepted protocols.
#
# The default is “tcp://0.0.0.0:9292”.
#
# bind 'tcp://0.0.0.0:9292'
# bind 'unix:///var/run/puma.sock'
# bind 'unix:///var/run/puma.sock?umask=0777'
# bind 'ssl://127.0.0.1:9292?key=path_to_key&cert=path_to_cert'
bind 'tcp://0.0.0.0:9292'

# Instead of “bind 'ssl://127.0.0.1:9292?key=path_to_key&cert=path_to_cert'” you
# can also use the “ssl_bind” option.
#
# ssl_bind '127.0.0.1', '9292', { key: path_to_key, cert: path_to_cert }

# Code to run before doing a restart. This code should
# close log files, database connections, etc.
#
# This can be called multiple times to add code each time.
#
# on_restart do
#   puts 'On restart...'
# end

# Command to use to restart puma. This should be just how to
# load puma itself (ie. 'ruby -Ilib bin/puma'), not the arguments
# to puma, as those are the same as the original process.
#
# restart_command '/u/app/lolcat/bin/restart_puma'

# === Cluster mode ===

# How many worker processes to run.
#
# The default is “0”.
#
# workers 2
workers 2

# Code to run when a worker boots to setup the process before booting
# the app.
#
# This can be called multiple times to add hooks.
#
# on_worker_boot do
#   puts 'On worker boot...'
# end

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end

# === Puma control rack application ===

# Start the puma control rack application on “url”. This application can
# be communicated with to control the main server. Additionally, you can
# provide an authentication token, so all requests to the control server
# will need to include that token as a query parameter. This allows for
# simple authentication.
#
# Check out https://github.com/puma/puma/blob/master/lib/puma/app/status.rb
# to see what the app has available.
#
# activate_control_app 'unix:///var/run/pumactl.sock'
# activate_control_app 'unix:///var/run/pumactl.sock', { auth_token: '12345' }
# activate_control_app 'unix:///var/run/pumactl.sock', { no_token: true }
EOTL
OFE

# ==========================================================================
# Added a unicorn.rb file to config/
# ==========================================================================
# run <<-OFE
# tee config/unicorn.rb <<EOTL
# # in general, 3 workers seems to be the best. Smaller apps can increase this
# worker_processes 3

# # Load the app into the master before forking workers for super-fast worker
# # spawn times
# preload_app true

# # immediately restart any workers that haven't responded within 30 seconds
# timeout 30

# # queue_classic PID
# # @qc_pid = nil

# before_fork do |server, worker|
#   # @qc_pid ||= spawn( "bundle exec rake qc:work" )
#   if defined?(ActiveRecord::Base)
#     ActiveRecord::Base.establish_connection
#   end
# end

# after_fork do |server, worker|
#   # @qc_pid ||= spawn( "bundle exec rake qc:work" )
#   if defined?(ActiveRecord::Base)
#     ActiveRecord::Base.establish_connection
#   end
# end
# EOTL
# OFE

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
    add_group 'ValueObjects',   'app/value_objects'
    add_group 'ServiceObjects', 'app/service_objects'
    add_group 'FormObjects',    'app/form_objects'
    add_group 'QueryObjects',   'app/query_objects'
    add_group 'ViewObjects',    'app/view_objects'
    add_group 'PolicyObjects',  'app/policy_objects'
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
      cane.abc_max      = 10
      cane.no_style     = false
      cane.abc_exclude  = %w(Foo::Bar#some_method)
      cane.add_threshold 'coverage/covered_percent', :>=, 99
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
    %w(db:drop db:create db:schema:load db:seed db:test:prepare).each do |task|
      Rake::Task[task].invoke
    end
  end

  desc 'ReSeed the database'
  task :reseed => :environment do
    %w(db:drop db:create db:migrate db:seed db:test:prepare).each do |task|
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
      # system('cd ' + Rails.root.to_s + ' metric_fu -r')
      system 'metric_fu -r'
    end

    desc "Run Brakeman"
    task :security do
      # system 'cd ' + Rails.root.to_s + ' brakeman -d -o tmp/security.html'
      system 'brakeman -d -o coverage/brakeman/security.html'
    end

    desc "Run Turbulence"
    task :turbulence do
      system 'bule'
    end

    desc "Run all Reports"
    task :all do
      Rake::Task['report:coverage'].invoke
      Rake::Task['report:metrics'].invoke
      Rake::Task['report:security'].invoke
      Rake::Task['report:cane'].invoke
      Rake::Task['report:turbulence'].invoke
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

  desc "Feature tests"
  Rake::TestTask.new(:features) do |t|
    t.libs << "test"
    t.pattern = "test/features/**/*_test.rb"
    t.verbose = true
  end

  desc "Library tests"
  Rake::TestTask.new(:libraries) do |t|
    t.libs << "test"
    t.pattern = "test/lib/**/*_test.rb"
    t.verbose = true
  end

  desc "Decorator Tests"
  Rake::TestTask.new(:decorators) do |t|
    t.libs << "test"
    t.pattern = "test/decorators/**/*_test.rb"
    t.verbose = true
  end

  desc "Value Object Tests"
  Rake::TestTask.new(:value_objects) do |t|
    t.libs << "test"
    t.pattern = "test/value_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "Service Object Tests"
  Rake::TestTask.new(:service_objects) do |t|
    t.libs << "test"
    t.pattern = "test/service_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "Form Object Tests"
  Rake::TestTask.new(:form_objects) do |t|
    t.libs << "test"
    t.pattern = "test/form_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "Query Object Tests"
  Rake::TestTask.new(:query_objects) do |t|
    t.libs << "test"
    t.pattern = "test/query_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "View Object Tests"
  Rake::TestTask.new(:view_objects) do |t|
    t.libs << "test"
    t.pattern = "test/view_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "Policy Object Tests"
  Rake::TestTask.new(:policy_objects) do |t|
    t.libs << "test"
    t.pattern = "test/policy_objects/**/*_test.rb"
    t.verbose = true
  end

  desc "Run with SimpleCov"
  Rake::TestTask.new(:coverage) do |t|
    require 'simplecov'
    SimpleCov.start 'rails'
    t.libs << "test"
    t.pattern = "test/**/**/**/*_test.rb"
    t.verbose = true
  end
end

Rake::Task[:test].enhance do |t|
  t.test_files  = FileList['test/**/**/**/*_test.rb']
  t.verbose     = true
end

# Rake::Task[:test].enhance do
#   Rake::Task["test:acceptance"].invoke
#   Rake::Task["test:features"].invoke
#   Rake::Task["test:libraries"].invoke
#   Rake::Task["test:decorators"].invoke
#   Rake::Task["test:value_objects"].invoke
#   Rake::Task["test:service_objects"].invoke
#   Rake::Task["test:form_objects"].invoke
#   Rake::Task["test:query_objects"].invoke
#   Rake::Task["test:view_objects"].invoke
#   Rake::Task["test:policy_objects"].invoke
# end
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
      rake secret | head -n1 | awk '{ print "SECRET_TOKEN=" $1 }' > .env
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
#   namespace :v1, constraints: PrivateApiConstraints.new(version: 1, default: true) do
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

initializer "disable_xml_params.rb" do <<-'RUBY'
# Protect against injection attacks
# http://www.kb.cert.org/vuls/id/380039
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML)
  RUBY
end

initializer "errors.rb" do <<-'RUBY'
require 'net/http'
require 'net/smtp'

# Example:
#   begin
#     some http call
#   rescue *HTTP_ERRORS => error
#     notify_hoptoad error
#   end

HTTP_ERRORS = [Timeout::Error,
               Errno::EINVAL,
               Errno::ECONNRESET,
               EOFError,
               Net::HTTPBadResponse,
               Net::HTTPHeaderSyntaxError,
               Net::ProtocolError]

SMTP_SERVER_ERRORS = [TimeoutError,
                      IOError,
                      Net::SMTPUnknownError,
                      Net::SMTPServerBusy,
                      Net::SMTPAuthenticationError]

SMTP_CLIENT_ERRORS = [Net::SMTPFatalError,
                      Net::SMTPSyntaxError]

SMTP_ERRORS = SMTP_SERVER_ERRORS + SMTP_CLIENT_ERRORS
  RUBY
end

initializer "rack-timeout.rb" do <<-'RUBY'
Rack::Timeout.timeout = (ENV['TIMEOUT_IN_SECONDS'] || 5).to_i
  RUBY
end

config = <<-RUBY

  # Enable deflate / gzip compression of controller-generated responses
  config.middleware.use Rack::Deflater
RUBY

inject_into_file 'config/environments/production.rb', config,
        :after => "config.serve_static_assets = false\n"



action_on_unpermitted_parameters = <<-RUBY
\n
  # Raise an ActionController::UnpermittedParameters exception when
  # a parameter is not explcitly permitted but is passed anyway.
  config.action_controller.action_on_unpermitted_parameters = :raise
RUBY

inject_into_file(
  "config/environments/development.rb",
  action_on_unpermitted_parameters,
  before: "\nend"
)

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
# run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"
# run "mv app/assets/javascripts/application.js app/assets/javascripts/application.js.coffee"
# run "sed -i '' /require_tree/d app/assets/stylesheets/application.css.scss"

# if @bourbon
#   run "echo >> app/assets/stylesheets/application.css.scss"
#   run "echo '@import \"bourbon\";' >>  app/assets/stylesheets/application.css.scss"
#   run "echo '@import \"neat\";' >>  app/assets/stylesheets/application.css.scss"
# end

# run "echo '#= require jquery\n#= require jquery_ujs\n#= require turbolinks\n#= require_tree .' > app/assets/javascripts/application.js.coffee"

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
tee app/domain_objects/decorators/decorate.rb <<EOTL
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
# Add a setup script to setup the application
# ==========================================================================
run <<-EOF
tee bin/setup <<EOTL
#!/usr/bin/env bash
set -e

# install gems
./bin/bundle install

# create config/database.yml file
./bin/rake db:config:create --trace

# create database(s)
./bin/rake db:create --trace

# migrate those databases
./bin/rake db:migrate --trace

# input seed data into the database
./bin/rake db:seed --trace

# Set up configurable environment variables
if [ ! -f .env ]; then
  cp .env.dev .env
fi

# Pick a port for Foreman
echo "port: 7000" > .foreman

# Set up DNS via Pow
if [ -d ~/.pow ]
then
  echo 7000 > ~/.pow/`basename $PWD`
else
  echo "Pow not set up but the team uses it for this project. Setup: http://goo.gl/RaDPO"
fi

EOTL
EOF
run 'chmod a+x bin/setup'

# ==========================================================================
# Add a jenkins script for CI setup
# ==========================================================================
run <<-EOF
tee bin/jenkins <<EOTL
#!/usr/bin/env bash

set -e

# install gems
./bin/bundle install

# create config/database.yml file
./bin/rake db:config:jenkins[jenkins,jankyjenkins] --trace

# create database(s)
./bin/rake db:create --trace

# migrate those databases
./bin/rake db:migrate --trace

# build test database from the schema
./bin/rake db:test:prepare --trace

# run all tests
./bin/rake test

EOTL
EOF
run 'chmod a+x bin/jenkins'

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
  <body class='' ng-app>
    <!--[if lt IE 7]>
      <p class="chromeframe">You are using an <strong>outdated</strong> browser. Please <a href="http://browsehappy.com/">upgrade your browser</a> or <a href="http://www.google.com/chromeframe/?redirect=true">activate Google Chrome Frame</a> to improve your experience.</p>
    <![endif]-->

    <header class='header'>
      <%= render 'header'>
    </header>

    <section class='col-xs-12'>
      <%= render "flash_messages" %>
    </section>

    <main class='main-section' role='main'>
      <%= yield %>
    </main>

    <footer class='footer'>
      <%= render 'footer'>
    </footer>

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

# # ==========================================================================
# # Add Bootstrap to the 'Assets to be Precompiled' list
# # ==========================================================================
# run <<-EOF
# tee config/environments/assets_to_precompile.rb <<EOTL
# # Assets to Precompile
# #
# # Use a module to manage the assets that are added and need to be precompiled
# # so we don't have to add them to each environment.
# #
# module AssetsToPrecompile
#   extend self

#   # JavaScript and CSS Assets
#   def list
#     stylesheets + javascripts
#   end

#   def javascripts
#     %w|bootstrap.js|
#   end

#   def stylesheets
#     %w|bootstrap.css|
#   end
# end
# EOTL
# EOF

# gsub_file "config/environments/production.rb", /# config.assets.precompile \+= %w\( search\.js \)/, "require_relative 'assets_to_precompile'\n  config.assets.precompile += AssetsToPrecompile.list"


# ==========================================================================
# Move the Readme to Markdown
# ========================================================================
run "rm README.rdoc"
run "echo '# Readme' > Readme.mkd"


# # ==========================================================================
# # Move the Secret Token to use ENV
# # ========================================================================
# #
# # This needs to run after bundler has ran
# #
# gsub_file "config/initializers/secret_token.rb", /= '\w+'/, "= ENV['secret_token']"
# run <<-EOF
# rake secret | head -n1 | awk '{ print "session_token: " $1 }' > .env
# EOF

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

puts
puts "---> Completed"

at_exit do
  run <<-EOF
git add --all
git commit -am "Finished stubbing application"
  EOF
end

# ==========================================================================
#
# ==========================================================================

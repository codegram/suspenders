module Suspenders
  class AppBuilder < Rails::AppBuilder
    include Suspenders::Actions

    def readme
      template 'README.md.erb', 'README.md'
    end

    def raise_on_delivery_errors
      replace_in_file 'config/environments/development.rb',
        'raise_delivery_errors = false', 'raise_delivery_errors = true'
    end

    def set_test_delivery_method
      inject_into_file(
        "config/environments/development.rb",
        "\n  config.action_mailer.delivery_method = :test",
        after: "config.action_mailer.raise_delivery_errors = true",
      )
    end

    def raise_on_unpermitted_parameters
      config = <<-RUBY
    config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      inject_into_class "config/application.rb", "Application", config
    end

    def provide_setup_script
      template "bin_setup.erb", "bin/setup", port_number: port, force: true
      run "chmod a+x bin/setup"
    end

    def provide_dev_prime_task
      copy_file 'development_seeds.rb', 'lib/tasks/development_seeds.rake'
    end

    def configure_generators
      config = <<-RUBY

    config.generators do |generate|
      generate.helper false
      generate.javascript_engine false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def set_up_factory_girl_for_rspec
      copy_file 'factory_girl_rspec.rb', 'spec/support/factory_girl.rb'
    end

    def configure_newrelic
      template 'newrelic.yml.erb', 'config/newrelic.yml'
    end

    def configure_smtp
      copy_file 'smtp.rb', 'config/smtp.rb'

      prepend_file 'config/environments/production.rb',
        %{require Rails.root.join("config/smtp")\n}

      config = <<-RUBY

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = SMTP_SETTINGS
      RUBY

      inject_into_file 'config/environments/production.rb', config,
        :after => 'config.action_mailer.raise_delivery_errors = false'
    end

    def configure_rollbar
      copy_file 'rollbar.rb', 'config/initializers/rollbar.rb'
    end

    def configure_rollout
      copy_file 'rollout.rb', 'config/initializers/rollout.rb'
    end

    def configure_lograge
      config = <<-RUBY

  config.lograge.enabled = true
      RUBY

      inject_into_file( "config/environments/production.rb", "\n\n  #{config}", before: "\nend")
    end

    def configure_dalli
      config = <<-RUBY

  config.cache_store = :dalli_store,
                    (ENV["MEMCACHIER_SERVERS"] || "").split(","),
                    {:username => ENV["MEMCACHIER_USERNAME"],
                     :password => ENV["MEMCACHIER_PASSWORD"],
                     :failover => true,
                     :socket_timeout => 1.5,
                     :socket_failure_delay => 0.2
                    }
      RUBY

      inject_into_file( "config/environments/production.rb", "\n\n  #{config}", before: "\nend")
    end

    def setup_secret_token
      template 'secrets.yml', 'config/secrets.yml', force: true
    end

    def disallow_wrapping_parameters
      remove_file "config/initializers/wrap_parameters.rb"
    end

    def create_partials_directory
      empty_directory 'app/views/application'
    end

    def create_shared_flashes
      copy_file "_flashes.html.slim", "app/views/application/_flashes.html.slim"
      copy_file "flashes_helper.rb", "app/helpers/flashes_helper.rb"
    end

    def create_shared_javascripts
      copy_file '_javascript.html.slim', 'app/views/application/_javascript.html.slim'
    end

    def create_application_layout
      template 'suspenders_layout.html.slim.erb',
        'app/views/layouts/application.html.slim',
        force: true
    end

    def use_postgres_config_template
      template 'postgresql_database.yml.erb', 'config/database.yml',
        force: true
    end

    def create_database
      bundle_command 'exec rake db:create db:migrate'
    end

    def replace_gemfile
      remove_file 'Gemfile'
      template 'Gemfile.erb', 'Gemfile'
    end

    def set_ruby_to_version_being_used
      create_file '.ruby-version', "#{Suspenders::RUBY_VERSION}\n"
    end

    def setup_heroku_specific_gems
      inject_into_file(
        "Gemfile",
        %{\n\s\sgem "rails_stdout_logging"},
        after: /group :production do/
      )
      inject_into_file(
        "Gemfile",
        %{\n\s\sgem "heroku-deflater"},
        after: /group :production do/
      )
    end

    def enable_database_cleaner
      copy_file 'database_cleaner_rspec.rb', 'spec/support/database_cleaner.rb'
    end

    def configure_spinach
      empty_directory_with_keep_file 'features'
      empty_directory_with_keep_file 'features/steps'
      empty_directory_with_keep_file 'features/support'
      copy_file "spinach_capybara.rb", "features/support/capybara.rb"
      copy_file "spinach_current_user.rb", "features/support/current_user.rb"
      copy_file "spinach_env.rb", "features/support/env.rb"
      copy_file "spinach_rails_helpers.rb", "features/support/rails_helpers.rb"
      copy_file "spinach_warden.rb", "features/support/warden.rb"
    end

    def configure_rspec
      remove_file "spec/rails_helper.rb"
      remove_file "spec/spec_helper.rb"
      copy_file "rails_helper.rb", "spec/rails_helper.rb"
      copy_file "spec_helper.rb", "spec/spec_helper.rb"
    end

    def configure_i18n_for_test_environment
      copy_file "i18n.rb", "spec/support/i18n.rb"
    end

    def configure_i18n_for_missing_translations
      raise_on_missing_translations_in("development")
      raise_on_missing_translations_in("test")
    end

    def configure_i18n_tasks
      run "cp $(i18n-tasks gem-path)/templates/rspec/i18n_spec.rb spec/"
      copy_file "config_i18n_tasks.yml", "config/i18n-tasks.yml"
    end

    def configure_action_mailer_in_specs
      copy_file 'action_mailer.rb', 'spec/support/action_mailer.rb'
    end

    def configure_guard
      copy_file 'Guardfile', 'Guardfile'
    end

    def configure_time_formats
      remove_file "config/locales/en.yml"
      template "config_locales_en.yml.erb", "config/locales/en.yml"
    end

    def configure_rack_timeout
      rack_timeout_config = <<-RUBY
Rack::Timeout.timeout = (ENV["RACK_TIMEOUT"] || 10).to_i
      RUBY

      append_file "config/environments/production.rb", rack_timeout_config
    end

    def configure_simple_form
      bundle_command "exec rails generate simple_form:install"
    end

    def configure_action_mailer
      action_mailer_host "development", %{"localhost:#{port}"}
      action_mailer_host "test", %{"www.example.com"}
      action_mailer_host "production", %{ENV.fetch("HOST")}
    end

    def configure_active_job
      # configure_application_file(
      #   "config.active_job.queue_adapter = :delayed_job"
      # )
      configure_environment "test", "config.active_job.queue_adapter = :inline"
    end

    def fix_i18n_deprecation_warning
      config = <<-RUBY
    config.i18n.enforce_available_locales = true
      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def generate_rspec
      generate 'rspec:install'
    end

    def configure_puma
      copy_file 'puma.rb', 'config/puma.rb'
    end

    def setup_foreman
      copy_file 'sample.env', '.sample.env'
      copy_file 'Procfile', 'Procfile'
    end

    def setup_stylesheets
      remove_file 'app/assets/stylesheets/application.css'
      copy_file 'application.css.scss',
        'app/assets/stylesheets/application.css.scss'
    end

    def setup_scripts
      remove_file 'app/assets/javascripts/application.js'
      copy_file 'application.js',
        'app/assets/javascripts/application.js'
    end

    def gitignore_files
      remove_file '.gitignore'
      copy_file 'suspenders_gitignore', '.gitignore'
      [
        'app/views/pages',
        'spec/lib',
        'spec/controllers',
        'spec/helpers',
        'spec/support/matchers',
        'spec/support/mixins',
        'spec/support/shared_examples'
      ].each do |dir|
        run "mkdir #{dir}"
        run "touch #{dir}/.keep"
      end
    end

    def init_git
      run 'git init'
    end

    def create_production_heroku_app(flags)
      app_name = heroku_app_name_for("production")

      run_heroku "create #{app_name} #{flags}", "production"
    end

    def create_heroku_apps(flags)
      create_production_heroku_app(flags)
    end

    def set_heroku_remotes
      remotes = <<-SHELL

# Set up the production apps.
#{join_heroku_app('production')}
      SHELL

      append_file 'bin/setup', remotes
    end

    def join_heroku_app(environment)
      heroku_app_name = heroku_app_name_for(environment)
      <<-SHELL
if heroku join --app #{heroku_app_name} &> /dev/null; then
  git remote add #{environment} git@heroku.com:#{heroku_app_name}.git || true
  printf 'You are a collaborator on the "#{heroku_app_name}" Heroku app\n'
else
  printf 'Ask for access to the "#{heroku_app_name}" Heroku app\n'
fi
      SHELL
    end

    def set_heroku_rails_secrets
      %w(production).each do |environment|
        run_heroku "config:add SECRET_KEY_BASE=#{generate_secret}", environment
      end
    end

    def set_heroku_serve_static_files
      %w(production).each do |environment|
        run_heroku "config:add RAILS_SERVE_STATIC_FILES=true", environment
      end
    end

    def provide_deploy_script
      copy_file "bin_deploy", "bin/deploy"

      instructions = <<-MARKDOWN

## Deploying

If you have previously run the `./bin/setup` script,
you can deploy to production with:

    $ ./bin/deploy production
      MARKDOWN

      append_file "README.md", instructions
      run "chmod a+x bin/deploy"
    end

    def create_github_repo(repo_name)
      path_addition = override_path_for_tests
      run "#{path_addition} hub create #{repo_name}"
    end

    def setup_google_analytics
      copy_file '_analytics.html.slim',
        'app/views/application/_analytics.html.slim'
    end

    def copy_miscellaneous_files
      copy_file "errors.rb", "config/initializers/errors.rb"
      copy_file "json_encoding.rb", "config/initializers/json_encoding.rb"
    end

    def customize_error_pages
      meta_tags =<<-EOS
  <meta charset="utf-8" />
  <meta name="ROBOTS" content="NOODP" />
  <meta name="viewport" content="initial-scale=1" />
      EOS

      %w(500 404 422).each do |page|
        inject_into_file "public/#{page}.html", meta_tags, :after => "<head>\n"
        replace_in_file "public/#{page}.html", /<!--.+-->\n/, ''
      end
    end

    def remove_routes_comment_lines
      replace_in_file 'config/routes.rb',
        /Rails\.application\.routes\.draw do.*end/m,
        "Rails.application.routes.draw do\nend"
    end

    def disable_xml_params
      copy_file 'disable_xml_params.rb', 'config/initializers/disable_xml_params.rb'
    end

    def setup_default_rake_task
      append_file 'Rakefile' do
        <<-EOS
task(:default).clear
task default: [:spec]

if defined? RSpec
  task(:spec).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.verbose = false
  end
end
        EOS
      end
    end

    private

    def raise_on_missing_translations_in(environment)
      config = 'config.action_view.raise_on_missing_translations = true'

      uncomment_lines("config/environments/#{environment}.rb", config)
    end

    def override_path_for_tests
      if ENV['TESTING']
        support_bin = File.expand_path(File.join('..', '..', 'spec', 'fakes', 'bin'))
        "PATH=#{support_bin}:$PATH"
      end
    end

    def run_heroku(command, environment)
      path_addition = override_path_for_tests
      run "#{path_addition} heroku #{command} --remote #{environment}"
    end

    def generate_secret
      SecureRandom.hex(64)
    end

    def port
      @port ||= [3000, 4000, 5000, 7000, 8000, 9000].sample
    end

    def serve_static_files_line
      "config.serve_static_files = ENV['RAILS_SERVE_STATIC_FILES'].present?\n"
    end

    def heroku_app_name_for(environment)
      "#{app_name.dasherize}-#{environment}"
    end
  end
end

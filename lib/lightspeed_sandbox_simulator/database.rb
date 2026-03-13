# frozen_string_literal: true

require 'active_record'
require 'uri'

module LightspeedSandboxSimulator
  class Database
    MIGRATIONS_PATH = File.expand_path('db/migrate', __dir__)
    TEST_DATABASE = 'lightspeed_simulator_test'

    class << self
      def connect!(url)
        raise ArgumentError, 'Only PostgreSQL URLs are supported' unless url.match?(%r{\Apostgres(ql)?://})

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection.execute('SELECT 1')
        ActiveRecord::Base.logger = LightspeedSandboxSimulator.logger
        LightspeedSandboxSimulator.logger.info("Connected to #{sanitize_url(url)}")
      end

      def connected?
        ActiveRecord::Base.connection_pool.connected? && ActiveRecord::Base.connection.active?
      rescue StandardError
        false
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      end

      def create!(url)
        db_name = URI.parse(url).path.delete_prefix('/')
        admin_url = url.sub(%r{/[^/]+\z}, '/postgres')

        ActiveRecord::Base.establish_connection(admin_url)
        ActiveRecord::Base.connection.create_database(db_name)
        LightspeedSandboxSimulator.logger.info("Created database: #{db_name}")
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message.include?('already exists')

        LightspeedSandboxSimulator.logger.info("Database already exists: #{db_name}")
      ensure
        ActiveRecord::Base.connection_pool.disconnect!
      end

      def drop!(url)
        db_name = URI.parse(url).path.delete_prefix('/')
        admin_url = url.sub(%r{/[^/]+\z}, '/postgres')

        ActiveRecord::Base.establish_connection(admin_url)
        ActiveRecord::Base.connection.drop_database(db_name)
        LightspeedSandboxSimulator.logger.info("Dropped database: #{db_name}")
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message.include?('does not exist')

        LightspeedSandboxSimulator.logger.info("Database does not exist: #{db_name}")
      ensure
        ActiveRecord::Base.connection_pool.disconnect!
      end

      def migrate!
        raise Error, 'Database not connected' unless connected?

        ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).migrate
        LightspeedSandboxSimulator.logger.info('Migrations complete')
      end

      def seed!(business_type: :restaurant)
        raise Error, 'Database not connected' unless connected?

        load_factories!
        Seeder.seed!(business_type: business_type)
      end

      def database_url
        url = Configuration.database_url_from_file
        raise Error, 'DATABASE_URL not found in .env.json' unless url

        url
      end

      def test_database_url(base_url: nil)
        return "postgres://localhost:5432/#{TEST_DATABASE}" unless base_url

        uri = URI.parse(base_url)
        uri.path = "/#{TEST_DATABASE}"
        uri.to_s
      rescue URI::InvalidURIError
        "postgres://localhost:5432/#{TEST_DATABASE}"
      end

      private

      def sanitize_url(url)
        uri = URI.parse(url)
        has_password = !uri.password.nil?
        uri.user = '***' if uri.user
        uri.password = '***' if has_password
        uri.to_s
      rescue URI::InvalidURIError
        url.gsub(%r{://[^@]+@}, '://***:***@')
      end

      def load_factories!
        return if @factories_loaded

        factories_dir = File.expand_path('db/factories', __dir__)
        FactoryBot.definition_file_paths = [factories_dir] if Dir.exist?(factories_dir)
        FactoryBot.find_definitions
        @factories_loaded = true
      rescue StandardError => e
        LightspeedSandboxSimulator.logger.warn("Failed to load factories: #{e.message}")
      end
    end
  end
end

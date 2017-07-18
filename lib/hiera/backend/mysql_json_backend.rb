class Hiera
  module Backend
    class Mysql_json_backend

      def initialize(cache=nil)
        require 'json'
        if defined?(JRUBY_VERSION)
          require 'jdbc/mysql'
          require 'java'
        else
          begin
            require 'mysql2'
          rescue LoadError
            require 'rubygems'
            require 'mysql2'
          end
        end

        @cache = cache || Filecache.new

        Hiera.debug("Hiera mysql_json initialized")
      end

      def lookup(key, scope, order_override, resolution_type)
        # default answer is set to nil otherwise the lookup ends up returning
        # an Array of nils and causing a Puppet::Parser::AST::Resource failed with error ArgumentError
        # for any other lookup because their default value is overwriten by [nil,nil,nil,nil]
        # so hiera('myvalue', 'test1') returns [nil,nil,nil,nil]
        results = nil

        Hiera.debug("looking up #{key} in mysql_json Backend")
        Hiera.debug("resolution type is #{resolution_type}")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          sqlfile = Backend.datafile(:mysql_json, scope, source, "sql") || next

          next unless File.exist?(sqlfile)
          data = @cache.read(sqlfile, Hash, {}) do |datafile|
            YAML.load(datafile)
          end

          mysql_config = data.fetch(:dbconfig, {})
          mysql_host = mysql_config.fetch(:host, nil) || Config[:mysql_json][:host] || 'localhost'
          mysql_user = mysql_config.fetch(:user, nil) || Config[:mysql_json][:user]
          mysql_pass = mysql_config.fetch(:pass, nil) || Config[:mysql_json][:pass]
          mysql_port = mysql_config.fetch(:port, nil) || Config[:mysql_json][:port] || '3306'
          mysql_database = mysql_config.fetch(:database, nil) || Config[:mysql_json][:database]

          connection_hash = {
            host:      mysql_host,
            username:  mysql_user,
            password:  mysql_pass,
            database:  mysql_database,
            port:      mysql_port,
            reconnect: true
          }

          Hiera.debug("data #{data.inspect}")
          next if data.empty?
          next unless data.include?(key)

          Hiera.debug("Found #{key} in #{source}")

          new_answer = Backend.parse_answer(data[key], scope)

          sql_results = query(connection_hash, new_answer)

          next if sql_results.length != 1
          begin
            new_answer = JSON.parse(sql_results[0]['value'])
          rescue
            raise Exception, "JSON parse error for key '#{key}'." unless Config[:mysql_json][:ignore_json_parse_errors]
            Hiera.debug("Miserable failure while looking for #{key}.")
            next
          end

          case resolution_type.is_a?(Hash) ? :hash : resolution_type
          when :array
            raise Exception, "Hiera type mismatch for key '#{key}': expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            results ||= []
            results << new_answer
          when :hash
            raise Exception, "Hiera type mismatch for key '#{key}': expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            results ||= {}
            results = Backend.merge_answer(new_answer, results, resolution_type)
          else
            results = new_answer
            break
          end
        end
        results
      end

      def query(connection_hash, query)
        Hiera.debug("Executing SQL Query: #{query}")

        data = []
        mysql_host     = connection_hash[:host]
        mysql_user     = connection_hash[:username]
        mysql_pass     = connection_hash[:password]
        mysql_database = connection_hash[:database]
        mysql_port     = connection_hash[:port]

        if defined?(JRUBY_VERSION)
          Jdbc::MySQL.load_driver
          url = "jdbc:mysql://#{mysql_host}:#{mysql_port}/#{mysql_database}"
          props = java.util.Properties.new
          props.set_property :user, mysql_user
          props.set_property :password, mysql_pass

          conn = com.mysql.jdbc.Driver.new.connect(url, props)
          stmt = conn.create_statement

          res = stmt.execute_query(query)
          md = res.getMetaData
          numcols = md.getColumnCount

          Hiera.debug("Mysql Query returned #{numcols} rows")

          while res.next
            if numcols < 2
              Hiera.debug("Mysql value : #{res.getString(1)}")
              data << res.getString(1)
            else
              row = {}
              (1..numcols).each do |c|
                row[md.getColumnName(c)] = res.getString(c)
              end
              data << row
            end
          end

        else
          client = Mysql2::Client.new(connection_hash)
          begin
            data = client.query(query).to_a
            Hiera.debug("Mysql Query returned #{data.size} rows")
          rescue => e
            Hiera.debug e.message
            data = nil
          ensure
            client.close
          end
        end

        data
      end
    end
  end
end

require 'yaml'
require 'rest-client'

module Olba
  class Receiver
    # when we last asked the service for updates
    attr_accessor :polled_at
    
    # the last time the service had updates for us
    attr_accessor :updated_at

    def initialize
      initialize_cluster_log
      @polled_at  = cluster_log[:polled_at]
      @updated_at = cluster_log[:updated_at]
    end

    def initialize_cluster_log
      if !File.exists?(Olba.configuration.cluster_log) || !cluster_log
        File.open(Olba.configuration.cluster_log, 'w') do |f|
          f.write({:polled_at => Time.now.to_i, :updated_at => Time.now.to_i}.to_yaml)
        end
      end
    end

    def cluster_log
      YAML.load_file(Olba.configuration.cluster_log)
    end

    def cluster_updated?
      @updated_at != cluster_log[:updated_at]
    end

    def needs_polling?
      cluster_log[:polled_at] < (Time.now.to_i - Olba.configuration.poll_interval)
    end

    def poll!
      RestClient.get(translation_resource_status_url) do |response, request, result|
        if response.code == 200
          remote_updated_at = Time.parse(response.to_str).to_i
        else
          remote_updated_at = cluster_log[:updated_at]
        end
        File.open(Olba.configuration.cluster_log, 'w') do |f|
          f.write({:polled_at => Time.now.to_i, :updated_at => remote_updated_at}.to_yaml)
        end
      end
      # get updated_at from server
    end

    def get_translations!
      RestClient.get(translation_resource_url) do |response, request, result|
        Olba.log([translation_resource_url, response.code].join(' - '))
        if response.code == 200
          File.open(File.join(Olba.configuration.project_root, 'config', 'locales', 'olba.yml'), 'w') do |f|
            f.write(response.to_str)
          end
        end
      end
    end

    def translation_resource_url
      "http://#{Olba.configuration.host}:#{Olba.configuration.port}/translations.yml?api_key=#{Olba.configuration.api_key}"
    end

    def translation_resource_status_url
      "http://#{Olba.configuration.host}:#{Olba.configuration.port}/translations/updated_at?api_key=#{Olba.configuration.api_key}"
    end
  end
end
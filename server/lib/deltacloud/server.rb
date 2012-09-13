# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

require 'rubygems'
require 'crack'
require 'json'
require 'yaml'
require 'haml'
require 'sinatra/base'
require 'sinatra/rabbit'

require_relative '../sinatra'
require_relative './models'
require_relative './drivers'
require_relative './helpers'
require_relative './collections'

module Deltacloud
  class API < Collections::Base

    # Enable logging
    # NOTE: Jruby use different logging mechanism not complatible with our
    # logger.
    use Deltacloud[:deltacloud].logger unless RUBY_PLATFORM == 'java'
    use Rack::Date
    use Rack::ETag
    use Rack::DriverSelect

    include Deltacloud::Helpers
    include Deltacloud::Collections

    set :config, Deltacloud[:deltacloud]

    get '/' do
      if driver.name == "openstack" or params[:force_auth]
        return [401, 'Authentication failed'] unless driver.valid_credentials?(credentials)
        if driver.name == "openstack"
          Deltacloud.config["openstack_creds"] = credentials
          #or here also works: Thread.current["openstack_creds"] = credentials
        end
      end
      respond_to do |format|
        format.xml { haml :"api/show" }
        format.json { xml_to_json :"api/show" }
        format.html { haml :"api/show" }
      end
    end

    options '/' do
      headers 'Allow' => supported_collections { |c| c.collection_name }.join(',')
    end

    post '/' do
      param_driver, param_provider = params["driver"], params["provider"]
      if param_driver
        redirect "#{root_url};driver=#{param_driver}", 301
      elsif param_provider && param_provider != "default"
        if request.referrer and request.referrer[/\;(driver)=(\w*).*$/i]
          redirect "#{root_url};driver=#{$2}\;provider=#{param_provider}", 301
        else
          redirect "#{root_url};provider=#{param_provider}", 301
        end
      else
        redirect url('/'), 301
      end
    end

  end
end


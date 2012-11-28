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

class CIMI::Model::Volume < CIMI::Model::Base

  acts_as_root_entity

  text :state

  text :type

  text :capacity

  text :bootable

  array :snapshots do
    scalar :ref
  end

  array :meters do
    scalar :ref
  end

  array :operations do
    scalar :rel, :href
  end

  def self.find(id, context)
    volumes = []
    opts = ( id == :all ) ? {} : { :id => id }
    volumes = context.driver.storage_volumes(context.credentials, opts)
    volumes.collect!{ |volume| from_storage_volume(volume, context) }
    return volumes.first unless volumes.length > 1 || volumes.length == 0
    return volumes
  end

  def self.all(context); find(:all, context); end

  def self.create_from_json(json_in, context)
    json = JSON.parse(json_in)
    volume_config_id = json["volumeTemplate"]["volumeConfig"]["href"].split("/").last
    volume_image_id = (json["volumeTemplate"].has_key?("volumeImage") ?
                json["volumeTemplate"]["volumeImage"]["href"].split("/").last  : nil)
    create_volume({:volume_config_id=>volume_config_id, :volume_image_id=>volume_image_id}, json, context)
  end

  def self.create_from_xml(xml_in, context)
    xml = XmlSimple.xml_in(xml_in)
    volume_config_id = xml["volumeTemplate"][0]["volumeConfig"][0]["href"].split("/").last
    volume_image_id = (xml["volumeTemplate"][0].has_key?("volumeImage") ?
             xml["volumeTemplate"][0]["volumeImage"][0]["href"].split("/").last  : nil)
    create_volume({:volume_config_id=>volume_config_id, :volume_image_id=>volume_image_id}, xml, context)
  end

  def self.delete!(id, context)
    context.driver.destroy_storage_volume(context.credentials, {:id=>id} )
    delete_attributes_for(Volume.new(:id => id))
  end

  def self.find_to_attach_from_json(json_in, context)
    json = JSON.parse(json_in)
    json["volumes"].map{|v| {:volume=>self.find(v["volume"]["href"].split("/volumes/").last, context),
                             :attachment_point=>v["attachmentPoint"]  }}
  end

  def self.find_to_attach_from_xml(xml_in, context)
    xml = XmlSimple.xml_in(xml_in)
    xml["volume"].map{|v| {:volume => self.find(v["href"].split("/volumes/").last, context),
                           :attachment_point=>v["attachmentPoint"] }}
  end

  def to_entity
    'volume'
  end

  private

  def self.create_volume(params, data, context)
    volume_config = CIMI::Model::VolumeConfiguration.find(params[:volume_config_id], context)
    opts = {:capacity=>context.from_kibibyte(volume_config.capacity, "GB"), :snapshot_id=>params[:volume_image_id] }
    storage_volume = context.driver.create_storage_volume(context.credentials, opts)
    store_attributes_for(context, storage_volume, data)
    from_storage_volume(storage_volume, context)
  end

  def self.from_storage_volume(volume, context)
    stored_attributes = context.load_attributes_for(volume)
    self.new( { :name => stored_attributes[:name] || volume.id,
                :description => stored_attributes[:description] || 'Description of Volume',
                :property => stored_attributes[:property],
                :created => volume.created.nil? ? nil : Time.parse(volume.created).xmlschema,
                :id => context.volume_url(volume.id),
                :capacity => context.to_kibibyte(volume.capacity, 'GB'),
                :bootable => "false", #fixme ... will vary... ec2 doesn't expose this
                :snapshots => [], #fixme...
                :type => 'http://schemas.dmtf.org/cimi/1/mapped',
                :state => volume.state,
                :meters => [],
                :operations => [{:href=> context.volume_url(volume.id), :rel => "delete"}]
            } )
  end

  def self.collection_for_instance(instance_id, context)
    instance = context.driver.instance(context.credentials, :id => instance_id)
    volumes = instance.storage_volumes.map do |mappings|
      mappings.keys.map { |volume_id| from_storage_volume(context.driver.storage_volume(context.credentials, :id => volume_id), context) }
    end.flatten
    CIMI::Model::VolumeCollection.new(
      :id => context.url("/machines/#{instance_id}/volumes"),
      :name => 'default',
      :count => volumes.size,
      :description => "Volume collection for Machine #{instance_id}",
      :entries => volumes
    )
  end

end

require 'uri'
require 'cgi'
require 'net/http'
require 'rexml/document'
require 'rubygems'
require 'xml/mapping'


module TheCloudMarket

  # -- forward definitions --
  
  class Region; end
  class Image; end
  class ImageOwner; end
 
  
  # Exception raised when the credentials are invalid for the given object
  class NotAuthorizedError < StandardError 
  end
  
  # Exception raised when the given object does not exist 
  class NotFoundError < StandardError
  end
  
  # Client class encapsulating access to the Web Services API of
  # http://thecloudmarket.com
  class Client
    
    # Initialization of a client instance. An API key must be given.
    #
    # If required, proxy settings (host and port) can also be provided. 
    # If the proxy requires authentication, user and password can also be given.
    #
    # Finally, an alterate base URL for the services can be given, 
    # which is useful for debugging
    def initialize(api_key, proxy_host = nil, proxy_port = nil, proxy_user = nil, proxy_pass = nil, tcm_url = 'http://thecloudmarket.com')
      @api_key = api_key
      @proxy_host = proxy_host
      @proxy_port = proxy_port
      @proxy_user = proxy_user
      @proxy_pass = proxy_pass
      @tcm_url = tcm_url
    end
    
    # Allows getting the ownership information for a given owner.
    # The information includes selected details about the images owned.
    #
    # +Requirements:+
    # Caller must be a member of the ownership
    # +Parameters:+
    # code: The unique id for the ownership. Can be discovered from the URL for the ownership page.
    #
    # +Returns+ the parsed TheCloudMarket::Ownership from the server
    #
    # 
    def ownership_info(ownership_id)
      xml = get("/owner/#{ownership_id}.xml" )
      ImageOwner.load_from_xml(REXML::Document.new(xml).root)
    end
    
    # Allows getting detailed information from an image.
    # +Requirements:+
    # Caller must own the image
    # +Parameters:+
    # code: The exteral image id (for instance ami-02cb2f6b).
    #
    # +Returns+ the parsed TheCloudMarket::Image from the server. 
    # If this is a machine image, it will contain also de information for the kernel and ramdisk.
    #
    # 
    def image_info(image_id)
      xml = get("/image/#{image_id}.xml" )
      Image.load_from_xml(REXML::Document.new(xml).root)
    end
    
    def update_image(image_internal_id, name, description) 
      get("/images/update_details/#{image_internal_id}.xml", {"image[name]" => name, "image[description]" => description})
    end
    
    def update_readme(image_internal_id, readme)
      post("/images/update_readme/#{image_internal_id}.xml", {"readme[content]" => readme})
    end

    def update_tags(image_internal_id, tags)
      get("/images/update_tags/#{image_internal_id}.xml", {"user_tags" => tags})
    end
    
    private
    def get(service, parameter_hash = {})
      args = {'api_key' => @api_key}.merge(parameter_hash)
      url = @tcm_url + service + '?' + args.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
      uri = URI.parse(url);
      resp = 
        Net::HTTP.Proxy(@proxy_host, @proxy_port, @proxy_user, @proxy_pass).get_response(uri)
      handle_response resp, url
    end
    
    def post(service, parameter_hash)
      uri = URI.parse(@tcm_url + service)
      args = {'api_key' => @api_key}.merge(parameter_hash)
      resp = Net::HTTP.post_form(uri, args)
      handle_response resp, uri
    end
    
    def handle_response(resp, url)
      case resp.code 
        when "200" then return resp.body
        when "404" then raise NotFoundError, "Object not found. #{url}"
        when "503" then raise NotAuthorizedError, "Not authorized. #{url}"
      else raise "Unexpected response. HTTP code #{resp.code}. #{url} \n#{resp.body}\n --- EOF ---"
      end
    end
  end
  
  class Region
    include XML::Mapping
    
    text_node :code, "code"
    text_node :name, "name"
  end
  
  class Image
    include XML::Mapping
    
    numeric_node :internal_id, "id" # id is used for object identity and causes warnings
    text_node :name, "name", :default_value => nil
    text_node :state, "state", :default_value => nil
    text_node :image_id, "image-id"
    text_node :architecture, "architecture", :default_value => nil
    boolean_node :public, "public", 'true', 'false'
    object_node :region, "region", :class => Region, :default_value => nil
    text_node :location, "location", :default_value => nil
    text_node :kind, "type", :default_value => nil # type is used by the Object Type
    object_node :kernel, "kernel", :class => Image, :default_value => nil
    object_node :ramdisk, "ramdisk", :class => Image, :default_value => nil
    text_node :created_at, "created-at"
    text_node :updated_at, "updated-at", :default_value => nil
    text_node :deleted_at, "deleted-at", :default_value => nil
    text_node :platform, "platform-definition/name", :default_value => nil
    text_node :description, "description", :default_value=>nil
    text_node :readme, "readme", :default_value=>nil
    numeric_node :owner_id, "owner-id", :default_value=>nil
  end
  
  class ImageOwner
    include XML::Mapping
    
    boolean_node :claimed, "claimed", 'true', 'false'
    text_node :code, "code"
    text_node :created_at, "created-at"
    text_node :description, "description", :default_value=>nil
    numeric_node :id, "id"
    text_node :name, "name", :default_value=>nil
    text_node :updated_at, "udpated-at", :default_value=>nil
    text_node :url, "url", :default_value=>nil
    hash_node :images, "images", "image", "image-id", :class=>Image, :default_value=>[]
  end
end
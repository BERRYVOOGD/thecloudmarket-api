load "the_cloud_market_client.rb"

# One-per-user: Listed in your account: http://192.168.1.7:3000/account
API_KEY = 'your-api-key'
# One-per-ownership: Last part of the ownership url: http://thecloudmarket.com/owner/809621114589
OWNERSHIP_ID = '809621114589'
# You problably keep your own database for published images.
# Let's pretend that you've read your db and got these contents
readmes = { 'ami-1205e27b' => '<h1>Readme description for ami-ca9e7aa3</h1><p>Nice!</p>', 
            'ami-doesnotexist' => '<p>An example of a missing image</p>' }
tags = { 'ami-1205e27b' => "example-tag, another", 
          'ami-doesnotexist' => 'last, tags, not, even, used' }


# Initialize the Client with your credentials (API KEY).
# Here we give additional parameters for the proxy host, port, user and password
# The last parameter allows you to test against a dummy service
client = TheCloudMarket::Client.new API_KEY,
    nil, nil, nil, nil, 'http://192.168.1.7:3000'

# Use your ownership id to get your information from TheCloudMarket:
own = client.ownership_info OWNERSHIP_ID

# Write the information to the console
puts <<EOF
Information for owner code: #{own.code}:
----------------------------------------
 - Name: #{own.name or "<not set>"}
 - This ownership has #{own.claimed ? '' : 'NOT'} been claimed already
 - Created at #{DateTime.parse(own.created_at)}
 - Owner information last updated at #{DateTime.parse(own.updated_at) rescue "<not set>"}
 - The owner provides more information at this url: #{own.url or "<not set>"}
 
 The following images are available from this owner:
EOF

# Information about the owned images is retrieved with the user
own.images.each_value do |img| 
  puts <<EOF
    [#{img.internal_id}] #{img.image_id}:#{img.name or "<name not set>"}.
     - #{img.kind} / #{img.architecture} / #{img.region.name}
     - Description: #{img.description or "<not set>"}
EOF
end


# Now do something interesting... Let's update the images

# Check every image and set a default name if it is missing
# Also count which kernels are the most used
kernels = Hash.new(0)
own.images.each_value do |img|
  info = client.image_info img.image_id
  kernels[info.kernel.image_id] += 1 if info.kernel 
  if info.description.nil? || info.description.empty?
    client.update_image(info.internal_id, info.name, "This image belongs to #{own.name or own.description or own.id}")
    puts "  + Image description updated for #{img.image_id}"
  elsif
    puts "  - Not updating #{img.image_id}. Current description <#{info.description}>"
  end
end

puts
puts "Kernel usage"
puts "------------"
kernels.each do |k,v|
  puts "  #{k} is used on #{v} images"
end

# Updating the README:
# Batch update readme for each image from some source


puts
puts "Updating readmes"
puts "----------------"

readmes.delete_if do |id, readme|
  image = own.images[id]
  client.update_readme(image.internal_id, readme) and (
    puts "  + Updated readme for #{id}"; true) unless image.nil?
end
unless readmes.empty?
  puts "  ! Some images could not be found on TheCloudMarket.com"
  readmes.each_key do |key|
    puts "     Image id: #{key}"
  end
end

# Updating TAGS:
# Update tags for images
puts
puts "Updating tags"
puts "----------------"

tags.delete_if do |id, tag|
  image = own.images[id]
  client.update_tags(image.internal_id, tag) and (
    puts "  + Updated tag for #{id}"; true) unless image.nil?
end
unless tags.empty?
  puts "  ! Some images could not be found on TheCloudMarket.com"
  tags.each_key do |key|
    puts "     Image id: #{key}"
  end
end

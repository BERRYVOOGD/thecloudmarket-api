load "the_cloud_market_client.rb"

client = TheCloudMarket::Client.new 'quentin_key', nil, nil, nil, nil, 'http://localhost:3000'

own = client.ownership_info '725966715235'
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

own.images.each_value do |img| 
  puts <<EOF
    [#{img.internal_id}] #{img.image_id}:#{img.name or "<name not set>"}.
     - #{img.kind} / #{img.architecture} / #{img.region.name}
     - Description: #{img.description or "<not set>"}
EOF
end

#
# Now do something interesting... Let's update the images

# Check every image and set a default name if it is missing
# Also count which kernels are the most used

kernels = Hash.new(0)
own.images.each_value do |img|
  info = client.image_info img.image_id
  kernels[info.kernel.image_id] += 1 if info.kernel 
  if info.description.nil? || info.description.empty?
    client.update_image(info.internal_id, info.name, "This image belongs to #{own.name or own.description or own.name}")
    puts "  + Image description updated"
  elsif
    puts "  - Not updating. Current description <#{info.description}>"
  end
end

puts
puts "Kernel usage"
puts "------------"
kernels.each do |k,v|
  puts "  #{k} is used on #{v} images"
end

# README:
# Batch update readme for each image from some source

# Let's pretend that this information is kept somewhere else.
# Then, it would be desirable to reuse the same information for updating thecloudmarket.com
readmes = { 'ami-a1a981d5' => 'Readme description for ami-a1a981d5', 
            'ami-6a917603' => 'Readme description for another image, this time is ami-6a917603',
            'ami-doesnotexist' => 'An example of a missing image' }
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

# TAGS:
# Update tags for images
tags = { 'ami-a1a981d5' => "example-tag, another, tagged-at-#{Time.new.to_s.gsub(' ', '_')}", 
          'ami-6a917603' => 'more, tags',
          'ami-doesnotexist' => 'last, tags, not, even, used' }
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

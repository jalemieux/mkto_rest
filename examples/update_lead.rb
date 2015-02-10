# $:.unshift(File.expand_path('../../lib/', __FILE__))
require_relative '../lib/mkto_rest'
# or require 'mkto_gem' if you installed the gem

require 'yaml'

=begin
This script looks for the hostname, client id and key in .mktorest.
Create that file with the following (yaml) format:

    ---
    :host: ''
    :client_id: ''
    :client_secret: ''

set your host name, client id and key to the right values.
=end

config_path = File.expand_path(File.join(File.dirname(__FILE__),'..', '.mktorest'))

if File.exist? config_path
  config = YAML::load_file(config_path)
else
  print <<-EOF
Set your host name, client id and key in #{config_path} in this format:

#{{ host: '', client_id: '', client_secret: '' }.to_yaml}

EOF
  exit 1
end
if ARGV.size < 2 or ARGV[0].include?('=')
  print "#{__FILE__} <lead_email> <key1=value2> <key2=value2> ...\n    e.g.: #{__FILE__} john@acme.com CS-Login=john@acme.com CS-EmailNames=Production\n\n"
  exit 1
end

attr_v = ARGV.shift
values = {}
ARGV.each do |pair|
  k, v = pair.split('=')
  values[k] = v
end



client = MktoRest::Client.new(config)

client.debug = true if $DEBUG   # from: ruby -d ...
#client.debug = true #verbose output, helps debugging

client.authenticate

# find leads, updated fields.
leads = client.get_leads :email, attr_v

leads.each do |lead|
  p "found lead: #{lead}"
  p lead.update values
end

# using a block
leads = client.get_leads :email, attr_v do |lead|
  p "found lead #{lead}"
end

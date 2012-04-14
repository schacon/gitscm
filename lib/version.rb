require 'httparty'

require 'dm-core'
require 'dm-serializer/to_json'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/local.db")

class Version
  include DataMapper::Resource
  include HTTParty

  property :version,    String
  property :commit_sha, String
  property :created_at, DateTime, :key => true

  base_uri 'https://api.github.com'
  default_params :output => 'json'
  format :json

  def <=>(other)
    aver = self.version.split(".").map { |x| x.to_i }
    bver = other.version.split(".").map { |x| x.to_i }

    return aver[0] <=> bver[0] if ((aver[0] <=> bver[0]) != 0)
    return aver[1] <=> bver[1] if ((aver[1] <=> bver[1]) != 0)
    return aver[2] <=> bver[2] if ((aver[2] <=> bver[2]) != 0)

    return -1 if aver[3].nil?
    return 1 if bver[3].nil?
    aver[3] <=> bver[3]
  end

  def self.get_versions
    # get a list of tags
    tags = get("/repos/gitster/git/git/refs/tags/").parsed_response

    # We're only interested ithe tags that have real git version numbers
    tags.delete_if { |tag| tag["ref"] !~ /^refs\/tags\/v[0-9.]+$/ }

    tags.each do |tag|
      version = tag["ref"][/v([0-9].+)$/, 1]
      next if Version.all(:version => version).length > 0
      next unless tag["object"]["type"] == "tag"
      tagobj = get(tag["object"]["url"]).parsed_response
      # If there's a problem with the server, let's pretend we didn't see it
      next if tagobj.nil? || tagobj["object"].nil?

      v = Version.new
      v.version = version
      v.commit_sha = tagobj["object"]["sha"]
      v.created_at = tagobj["tagger"]["date"]
      if v.save
        puts "Version #{version} saved"
      else
        puts "Version #{version} save failed"
      end
    end
  end
end

DataMapper.auto_upgrade!

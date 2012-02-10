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

  def self.get_versions
    # get a list of tags
    tags = get("/repos/gitster/git/git/refs/tags/").parsed_response
    tags.sort! {|a,b| b["ref"] <=> a["ref"] }
    # go through the tags to find the latest release
    tags.each do |tag|
      if m = /^refs\/tags\/v([0-9.]+)$/.match(tag["ref"])
        version = m[1]
        if Version.last(:version => version)
          puts "Already up to date"
          break
        else
          next unless tag["object"]["type"] == "tag"
          tagobj = get(tag["object"]["url"]).parsed_response
          v = Version.new
          v.version = version
          v.commit_sha = tagobj["object"]["sha"]
          v.created_at = tagobj["tagger"]["date"]
          if v.save
            puts "Version #{version} saved"
            break
          else
            puts "Version #{version} save failed"
          end
        end
      end
    end
  end
end

DataMapper.auto_upgrade!

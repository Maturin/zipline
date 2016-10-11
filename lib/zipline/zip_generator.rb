# this class acts as a streaming body for rails
# initialize it with an array of the files you want to zip
module Zipline
  class ZipGenerator
    # takes an array of pairs [[uploader, filename], ... ]
    def initialize(files)
      @files = files
    end

    #this is supposed to be streamed!
    def to_s
      throw "stop!"
    end

    def each(&block)
      fake_io_writer = ZipTricks::BlockWrite.new(&block)
      ZipTricks::Streamer.open(fake_io_writer) do |streamer|
        @files.each {|file, name| handle_file(streamer, file, name) }
      end
    end

    def handle_file(streamer, file, name)
      file = normalize(file)
      write_file(streamer, file, name)
    end

    def normalize(file)
      unless is_io?(file)
        if file.respond_to?(:url) || file.respond_to?(:expiring_url)
          file = file
        elsif file.respond_to? :file
          file = File.open(file.file)
        elsif file.respond_to? :path
          file = File.open(file.path)
        else
          raise(ArgumentError, 'Bad File/Stream')
        end
      end
      file
    end

    def write_file(streamer, file, name)
      streamer.write_deflated_file(name) do |writer_for_file|
        if file.respond_to?(:url) || file.respond_to?(:expiring_url)
          # expiring_url seems needed for paperclip to work
          the_remote_url = file.respond_to?(:expiring_url) ? file.expiring_url : file.url
          c = Curl::Easy.new(the_remote_url) do |curl|
            curl.on_body do |data|
              writer_for_file << data
              data.bytesize
            end
          end
          c.perform
        elsif is_io?(file)
          IO.copy_stream(file, writer_for_file)
        else
          raise(ArgumentError, 'Bad File/Stream')
        end
      end
    end

    def is_io?(io_ish)
      io_ish.respond_to? :read
    end
  end
end

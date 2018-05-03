# frozen_string_literal: true

require_relative '../../command'
require 'stringio'

module Lkr
  module Commands
    class Space
      class Export < Lkr::Command
        def initialize(options)
          super()
          @options = options
        end

        def execute(*args, input: $stdin, output: $stdout)
          say_warning("args: #{args.inspect}") if @options.debug
          say_warning("options: #{@options.inspect}") if @options.debug
          begin
            login
            if @options[:tar] || @options[:tgz] then
              arc_path = Pathname.new(@options[:tgz] || @options[:tar])
              arc_path = Pathname.new(File.expand_path(@options[:dir])) + arc_path unless arc_path.absolute?
              f = File.open(arc_path.to_path, "wb")
              tarfile = StringIO.new(String.new,"w")
              begin
                tw = Gem::Package::TarWriter.new(tarfile)
                process_space(args[0], tw)
                tw.flush
                tarfile.rewind
                if @options[:tgz]
                  gzw = Zlib::GzipWriter.new(f)
                  gzw.write tarfile.string
                  gzw.close
                else
                  f.write tarfile.string
                end
              ensure
                f.close
                tarfile.close
              end
            else
              process_space(args[0], @options[:dir])
            end
          ensure
            logout_all
          end
        end

        def process_space(space_id, base, rel_path = nil)
          space = query_space(space_id)
          path = Pathname.new(space.name)
          path = rel_path + path if rel_path

          write_file("Space_#{space.id}_#{space.name}.json", base, path) do |f|
            f.write JSON.pretty_generate(space.to_attrs.reject do |k,v|
              [:looks, :dashboards].include?(k)
            end)
          end
          space.looks.each do |l|
            look = query_look(l.id)
            write_file("Look_#{look.id}_#{look.title}.json", base, path) do |f|
              f.write JSON.pretty_generate(look.to_attrs) 
            end
          end
          space.dashboards.each do |d|
            dashboard = query_dashboard(d.id)
            write_file("Dashboard_#{dashboard.id}_#{dashboard.title}.json", base, path) do |f|
              f.write JSON.pretty_generate(dashboard.to_attrs)
            end
          end
          space_children = query_space_children(space_id)
          space_children.each do |child_space|
            process_space(child_space.id, base, path)
          end
        end
      end
    end
  end
end
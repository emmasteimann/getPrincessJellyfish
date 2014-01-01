require 'mechanize'
require 'logger'
require 'pry'
require 'zip'

class GetPrincessJellyFish
  attr_accessor :agent, :first_page, :chapter_markers, :range, :previous_url, :final_chapter

  def initialize(range)
    @agent = Mechanize.new
    @agent.log = Logger.new "mech.log"
    @agent.user_agent_alias = 'Mac Safari'
    @agent.follow_meta_refresh = false
    @agent.redirect_ok = false
    @range = range
  end

  def prep_chapters
    # Prep Chapter Markers
    page = @agent.get("http://www.mangareader.net/kuragehime")
    @chapter_markers = {}
    i = 1
    @first_page = 0
    load_chapter = 1
    if @range && @range.is_a?(Array)
      load_chapter = @range.first
    end
    chapter_anchors = page.search("//div[@id='chapterlist']//a")
    @final_chapter = chapter_anchors.count
    chapter_anchors.each{ |option|
      marker = option.attributes["href"].to_s
      @first_page = marker if i == load_chapter
      @chapter_markers[marker] = {chapter_id: i, chapter_name: option.text}
      i = i + 1
    }
  end

  def start_download
    cbz_dir = "princess_jellyfish_comics"
    raw_dir = "saved_comics"
    if File.directory?(cbz_dir)
      FileUtils.rm_rf(cbz_dir)
    end
    if File.directory?(raw_dir)
      FileUtils.rm_rf(raw_dir)
    end
    # Start with first page of first Chapter
    base_url = "http://www.mangareader.net"
    url = base_url
    page = @agent.get("#{url}#{@first_page}")
    puts @agent.current_page().uri()

    keep_going = true
    current_chapter = {}
    page_cursor = 1
    while keep_going
      page = @agent.current_page()
      current_page_id = page.uri().to_s.split("http://www.mangareader.net")[-1]
      chapter_start = @chapter_markers[current_page_id]
      if chapter_start
        zip_previous_chapter(current_chapter[:chapter_id]) if current_chapter[:chapter_id]
        current_chapter = chapter_start
        puts "Chapter switched to -> " + current_chapter[:chapter_id].to_s
        if @range && @range.is_a?(Array)
          if current_chapter[:chapter_id] > @range.last
            keep_going = false
            exit
          end
        end
      end

      comic_image = page.search("//img[@id='img']").first.attributes["src"].to_s
      image_name = comic_image.split('/')[-1]
      @agent.get("#{comic_image}").save("#{chapter_directory(current_chapter[:chapter_id])}/#{page_cursor}_#{image_name}")

      puts "Currently Downloading: #{current_chapter[:chapter_name]}"
      puts "Downloading comic address: #{comic_image}"

      stop_the_presses = false
      next_link = page.link_with(:text => "Next")
      if current_chapter[:chapter_id].to_i == @final_chapter
        next_number = next_link.href.split('/')[-1].to_i
        check_number = (page.search("//select[@id='pageMenu']//option").last.text.to_i + 1).to_s.to_i
        stop_the_presses = true if next_number > check_number
      end
      if next_link.href && !stop_the_presses
        next_page = @agent.get("#{url}#{next_link.href}")
        puts @agent.current_page().uri()
      else
        zip_previous_chapter(current_chapter[:chapter_id])
        keep_going = false
      end
      page_cursor = page_cursor + 1
    end
  end

  def chapter_directory(chapter_id)
    "princess_jellyfish_comics/princess_jellyfish_chapter_#{chapter_id}"
  end

  def zip_file_path(chapter_id)
    directory_name = "saved_comics"
    unless File.directory?(directory_name)
      FileUtils.mkdir_p(directory_name)
    end
    "#{directory_name}/princess_jellyfish_chapter_#{chapter_id}.cbz"
  end

  def zip_previous_chapter(chapter_id)
    directory = chapter_directory(chapter_id)
    zipfile_name = zip_file_path(chapter_id)
    if File.exist?(zipfile_name)
      File.delete(zipfile_name)
    end
    Zip::File.open(zipfile_name, 'w') do |zipfile|
      Dir["#{directory}/**/**"].reject{|f|f==zipfile_name}.each do |file|
        zipfile.add(file.sub(directory+'/',''),file)
      end
    end
  end

  class << self
    def new_download(range = nil)
      scary_downloader = self.new(range)
      scary_downloader.prep_chapters
      scary_downloader.start_download
    end
  end

end

GetPrincessJellyFish.new_download(nil)

exit

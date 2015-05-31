require 'rest-client'
require 'nokogiri'
require 'json'
require 'iconv'
require 'uri'
require 'pry'
require 'capybara'
require 'capybara/webkit'

# 難得寫註解，總該碎碎念。
class Crawler
  include Capybara::DSL
  attr_reader :semester_list, :courses_list, :query_url, :result_url

  DAYS = {
    "一" => 1,
    "二" => 2,
    "三" => 3,
    "四" => 4,
    "五" => 5,
    "六" => 6,
    "日" => 7,
  }

  def initialize(year: current_year, term: current_term, update_progress: nil, after_each: nil, params: {})
    # @query_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword"
    @query_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.CHI_query_keyword"
    @front_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/"
    Capybara.current_driver = :webkit
    Capybara.javascript_driver = :webkit
    @year = year
    @term = term
  end

  def prepare_post_data
    post_data = {
      :qYear => @year-1911,
      :qTerm => @term,
      :cour => " ",
      :seq1 => "A",
      :seq2 => "M"
    }
    r = RestClient.post(@query_url, post_data);
    ic = Iconv.new("utf-8//translit//IGNORE","big-5")
    @query_page = Nokogiri::HTML(ic.iconv(r.to_s))
    nil
  end

  def crawl
    visit @query_url

    within 'form[name="bill"]' do
      within 'select[name="qYear"]' do
        first("option[value=\"#{@year-1911}\"]").select_option
      end

      within 'select[name="qTerm"]' do
        first("option[value=\"#{@term}\"]").select_option
      end

      first('input[name="cour"]').set ' '
      click_on '送出查詢'
    end

    page.switch_to_window(page.windows.last)
    @query_page = Nokogiri::HTML(html)
  end

  def get_courses
    @courses = []

    @query_page.css('tbody')[1].css('tr:nth-child(2n+1)').each do |row|
      datas = row.css('td')
      datas[6] && datas[6].search('br').each {|d| d.replace("\n") }
      datas[12] && datas[12].search('br').each {|d| d.replace("\n") }

      # normalize timetable
      course_days = []
      course_periods = []
      course_locations = []
      # Todos: 可能需要獨立出實習課
      if not ( datas[12] && datas[12].text.include?("未維護") )
        datas[12].text.split("\n").each do |p_raw|
          m = p_raw.match(/(實習)?每週(?<d>.)(?<s>\d+)~(?<e>\d+)\s(?<loc>.+)?/)
          if !!m
            (m[:s].to_i..m[:e].to_i).each do |period|
               course_days << DAYS[m[:d]]
               course_periods << period
               course_locations << m[:loc]
            end
          end
        end
      end

      # code must be unique every term
      code = datas[3] && "#{@year}-#{@term}-#{datas[3].text}"

      m = datas[4] && datas[4].text.strip.scan(/(?<dep>(\(進修\))?[^(\s|\d)]+)(?<group>(\d|[A-Z])+)?(\s+)?(有擋修)?/)
      department = []
      if !!m
        department = m.map { |d| d[0] }
      end
      department.delete(" ")
      department.uniq!

      @courses << {
        year: @year,
        term: @term,
        code: code,
        department: department,
        required: datas[5] && datas[5].text.include?('必'),
        name: datas[6] && datas[6].text.split("\n")[0].gsub(/ /, ''),
        lecturer: datas[7] && datas[7].text.strip.split("\n").uniq.join(','),
        credits: datas[9] && datas[9].text.to_i,
        day_1: course_days[0],
        day_2: course_days[1],
        day_3: course_days[2],
        day_4: course_days[3],
        day_5: course_days[4],
        day_6: course_days[5],
        day_7: course_days[6],
        day_8: course_days[7],
        day_9: course_days[8],
        period_1: course_periods[0],
        period_2: course_periods[1],
        period_3: course_periods[2],
        period_4: course_periods[3],
        period_5: course_periods[4],
        period_6: course_periods[5],
        period_7: course_periods[6],
        period_8: course_periods[7],
        period_9: course_periods[8],
        location_1: course_locations[0],
        location_2: course_locations[1],
        location_3: course_locations[2],
        location_4: course_locations[3],
        location_5: course_locations[4],
        location_6: course_locations[5],
        location_7: course_locations[6],
        location_8: course_locations[7],
        location_9: course_locations[8],
      }
    end
  end

  def save_to(filename='courses.json')
    File.open(filename, 'w') {|f| f.write(JSON.pretty_generate(@courses))}
    File.open("ntpu_courses.json", 'w') do |f|
      new_courses = @courses.select {|d| d[:department].count == 1 or d[:department].count == 0}.map {|d| d[:department] = d[:department][0] if d[:department]; d}
      f.write(JSON.pretty_generate(new_courses))
    end
  end

  def current_year
    (Time.now.month.between?(1, 7) ? Time.now.year - 1 : Time.now.year)
  end

  def current_term
    (Time.now.month.between?(2, 7) ? 2 : 1)
  end
end


crawler = Crawler.new(year: 2014, term: 1)
crawler.crawl
# crawler.prepare_post_data(103, 1)
crawler.get_courses
crawler.save_to

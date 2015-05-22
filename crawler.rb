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

  def initialize
    # @query_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword"
    @query_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.CHI_query_keyword"
    @front_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/"
    Capybara.current_driver = :webkit
    Capybara.javascript_driver = :webkit
  end

  def prepare_post_data(year=103, term=2)
    post_data = {
      :qYear => year,
      :qTerm => term,
      :cour => " ",
      :seq1 => "A",
      :seq2 => "M"
    }
    r = RestClient.post(@query_url, post_data);
    ic = Iconv.new("utf-8//translit//IGNORE","big-5")
    @query_page = Nokogiri::HTML(ic.iconv(r.to_s))
    nil
  end

  def crawl(year=103, term=2)
    visit @query_url

    within 'form[name="bill"]' do
      within 'select[name="qYear"]' do
        first("option[value=\"#{year}\"]").select_option
      end

      within 'select[name="qTerm"]' do
        first("option[value=\"#{term}\"]").select_option
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

      periods = []
      # Todos: 實習
      if not ( datas[12] && datas[12].text.include?("未維護") )
        # if datas[3] && datas[3].text.include?('N2032')
        #   binding.pry
        # end
        datas[12].text.split("\n").each do |p_raw|
          m = p_raw.match(/(實習)?每週(?<d>.)(?<s>\d+)~(?<e>\d+)\s(?<loc>.+)?/)
          if !!m
            (m[:s].to_i..m[:e].to_i).each do |period|
               chars = []
               chars << m[:d]
               chars << period
               chars << m[:loc]
               periods << chars.join(',')
            end
          end
        end
      end

      @courses << {
        year: datas[1] && datas[1].text.to_i + 1911,
        term: datas[2] && datas[2].text.to_i,
        code: datas[3] && datas[3].text,
        required: datas[5] && datas[5].text.include?('必'),
        name: datas[6] && datas[6].text.split("\n")[0],
        lecturer: datas[7] && datas[7].text.strip.split("\n").join(','),
        credits: datas[9] && datas[9].text.to_i,
        periods: periods,
      }
    end
  end

  def save_to(filename='courses.json')
    File.open(filename, 'w') {|f| f.write(JSON.pretty_generate(@courses))}
  end
end


crawler = Crawler.new
crawler.crawl(103, 1)
# crawler.prepare_post_data(103, 1)
crawler.get_courses
crawler.save_to

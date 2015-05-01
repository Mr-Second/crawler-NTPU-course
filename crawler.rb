require 'rest-client'
require 'nokogiri'
require 'json'
require 'iconv'
require 'uri'

# 難得寫註解，總該碎碎念。
class Crawler
  attr_reader :semester_list, :courses_list, :query_url, :result_url

  def initialize
    @query_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword"
    @front_url = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/"
  end

  def prepare_post_data
    post_data = {
      :qYear => 103,
      :qTerm => 2,
      :cour => " ",
      :seq1 => "A",
      :seq2 => "M"
    }
    r = RestClient.post(@query_url, post_data);
    ic = Iconv.new("utf-8//translit//IGNORE","big-5")
    @query_page = Nokogiri::HTML(ic.iconv(r.to_s))
    nil
  end

  def get_courses
    # 初始 courses 陣列
    @courses = []
    puts "getting courses...\n"
    # 一一點進去YO
    @query_page.css('td:nth-of-type(2)').each_with_index do |row, index|
      # get every link to every classification
      # puts @front_url + row['href'].to_s
      puts "now on index: #{index}"
      puts @query_page.css('td:nth-of-type(7)')[index].text
      semester = @query_page.css('td:nth-of-type(2)')[index].text
      semester_year = @query_page.css('td:nth-of-type(3)')[index].text
      course_number = @query_page.css('td:nth-of-type(4)')[index].text
      must_learn_class = @query_page.css('td:nth-of-type(5)')[index].text
      required_unrequired = @query_page.css('td:nth-of-type(6)')[index].text
      course_name = @query_page.css('td:nth-of-type(7)')[index].text
      teacher = @query_page.css('td:nth-of-type(8)')[index].text
      classification = @query_page.css('td:nth-of-type(9)')[index].text
      credit = @query_page.css('td:nth-of-type(10)')[index].text
      hours = @query_page.css('td:nth-of-type(11)')[index].text
      language = @query_page.css('td:nth-of-type(12)')[index].text
      time_classroom = @query_page.css('td:nth-of-type(13)')[index].text
      must_learn_limit = @query_page.css('td:nth-of-type(14)')[index].text
      other_limit = @query_page.css('td:nth-of-type(15)')[index].text
      all_limit = @query_page.css('td:nth-of-type(16)')[index].text
      must_learn_chosen = @query_page.css('td:nth-of-type(17)')[index].text
      other_chosen = @query_page.css('td:nth-of-type(18)')[index].text
      all_chosen = @query_page.css('td:nth-of-type(19)')[index].text
      authorized_students = @query_page.css('td:nth-of-type(20)')[index].text
      wait_for_authorized = @query_page.css('td:nth-of-type(21)')[index].text

      r = RestClient.get @front_url + @query_page.css('td:nth-of-type(7)')[index].css('a').first['href'].to_s
      ic = Iconv.new("utf-8//translit//IGNORE","big-5")
      detail_page = Nokogiri::HTML(ic.iconv(r.to_s))

      if detail_page.css('tr.font-g13:contains("Required") td').css('.font-c13').nil?
        book = "none"
      elsif detail_page.css('tr.font-g13:contains("Required") td').css('.font-c13').text == ""
        book = "none"
      else
        book = detail_page.css('tr.font-g13:contains("Required") td').css('.font-c13').text
      end
      puts book

      @courses << {
        :semester => semester,
        :semester_year => semester_year,
        :course_number => course_number,
        :must_learn_class => must_learn_class,
        :required_unrequired => required_unrequired,
        :course_name => course_name,
        :teacher => teacher,
        :classification => classification,
        :credit => credit,
        :hours => hours,
        :language => language,
        :time_classroom => time_classroom,
        :must_learn_limit => must_learn_limit,
        :other_limit => other_limit,
        :all_limit => all_limit,
        :must_learn_chosen => must_learn_chosen,
        :other_chosen => other_chosen,
        :all_chosen => all_chosen,
        :authorized_students => authorized_students,
        :wait_for_authorized => wait_for_authorized,
        :book => book
        }
    end


  end


  def save_to(filename='courses_p1.json')
    File.open(filename, 'w') {|f| f.write(JSON.pretty_generate(@courses))}
  end
end


crawler = Crawler.new
crawler.prepare_post_data
crawler.get_courses
crawler.save_to

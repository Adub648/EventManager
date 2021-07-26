require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

# set initial values
def initializeCode
  @initial = true
  @popular_times = {}
  24.times { |hour| @popular_times.store(hour, 0) }
  @popular_date = { Monday: 0, Tuesday: 0, Wednesday: 0, Thursday: 0, Friday: 0, Saturday: 0, Sunday: 0 }
end

# clean up zipcode input
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

# clean up phone number input
def clean_home_phone(phone)
  phone.gsub!(/[^\d]/, '')
  if phone.length < 10 || phone.length > 11
    phone = nil
  elsif phone.length == 11 && phone.start_with?('0')
    phone.unshift(0)
  elsif phone.length == 11
    phone = nil
  end
  puts "Fixed phone number is #{phone}"
end

# find the popular hour and date for regisrations
def find_popular_time(time)
  time_array = []
  time_array += time.split(' ')
  begin
    # work out the weekday and add it to hash
    time_array[0] = Date.parse(time_array[0])
    weekday = time_array[0].wday
    find_popular_date(weekday)
  rescue
    time_array[0] = "Date could not be parsed."
  end
  begin
    # work out the hour and add it to hash
    time_array[1] = Time.parse(time_array[1])
    hour = time_array[1].hour
    find_popular_hour(hour)
  rescue
    time_array[1] = "Time could not be parsed."
  end
end

# add hour registered to array
def find_popular_hour(hour)
  @popular_times[hour] += 1
end

# add weekday regiestered to array
def find_popular_date(weekday)
  case weekday
  when 1
    @popular_date[:Monday] += 1
  when 2
    @popular_date[:Tuesday] += 1
  when 3
    @popular_date[:Wednesday] += 1
  when 4
    @popular_date[:Thursday] += 1
  when 5
    @popular_date[:Friday] += 1
  when 6
    @popular_date[:Saturday] += 1
  when 7
    @popular_date[:Sunday] += 1
  end
end

# get legislator info from google API based on zipcode
def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyB3PggisNX6PZKuCY7Mkr73bq64yttA83M'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# create and save thank you letter
def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# start the program
initializeCode

# output to console that program has started
puts 'EventManager initialized.'

# open the data and read it
contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# gather and format data for each row of table
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_home_phone(row[:homephone])
  time = find_popular_time(row[:regdate])

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

# calculate most popular hour and display
highest_hour = @popular_times.max_by { |k, v| v }
highest_hour[0] = highest_hour[0] > 12 ? (highest_hour[0] - 12).to_s + "pm" : highest_hour[0].to_s + "am"
puts "The hour with the most traffic is #{highest_hour[0]} with #{highest_hour[1]} registrations during that time."

# calculatr most popular weekday and display
highest_day = @popular_date.max_by { |k, v| v }
puts "The weekday with the most traffic is #{highest_day[0]} with #{highest_day[1]} regisrations during that time."

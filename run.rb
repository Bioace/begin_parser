require 'headless'
require "selenium-webdriver"
require 'yaml'
require 'json'

class BrowserDriver
	attr_reader :browser_type, :headless, :driver

	def initialize settings
		@use_profile_directory = settings[:use_profile_directory]
		@path_to_profile_dir = settings[:path_to_profile_dir]
		@proxy_address = settings[:proxy_address]
		@browser_type = settings[:browser_type]
		@proxy_port = settings[:proxy_port]
		@use_proxy = settings[:use_proxy]
		@headless = settings[:headless]

		at_exit do
			@driver.exit rescue nil
		end
	end

	def disconnect
		@driver.exit rescue nil
	end

	def restart_browser
		@driver.quit rescue nil
		prepare_browser
	end

	def prepare_browser
		case @browser_type
		when 'firefox'
		  prepare_browser_firefox
		when 'chrome'
		  prepare_browser_chrome
		else
		  puts "Error: browser not detected in config"
		  exit
		end
		@driver
	end

	def prepare_browser_chrome
		options = Selenium::WebDriver::Chrome::Options.new
		options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.80 Safari/537.36")
	 	options.add_argument("--user-data-dir=#{@path_to_profile_dir}") if @use_profile_directory
		options.add_argument("--proxy-server=#{@proxy_address}:#{@proxy_port}") if @use_proxy
		options.add_argument('--headless') if @headless
		options.add_argument("--window-size=1920,1080")

		@driver = Selenium::WebDriver.for :chrome, options: options
	end

	def prepare_browser_firefox
		profile = Selenium::WebDriver::Firefox::Profile.new
		profile['general.useragent.override'] = 'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10'
		if @use_proxy
			profile['network.proxy.http'] = @proxy_address
			profile['network.proxy.http_port'] = @proxy_port
		end
		# TODO: user-data-dir, window-size
		args = []
		args.push '-headless' if @headless
		options = Selenium::WebDriver::Firefox::Options.new(args: args)
		@driver = Selenium::WebDriver.for(:firefox, options: options, :profile => profile)
	end
end

config = YAML::load_file(File.expand_path('../config/config.yml', __FILE__))
settings = {
	:browser_type => config['browser'],
	:headless => config['headless'],
	:use_profile_directory => config['use_profile_directory'],
	:use_proxy => config['use_proxy'],
	:path_to_profile_dir => config["path_to_profile_dir"],
	:proxy_address => config["proxy_address"],
	:proxy_port => config["proxy_port"]
}
browser_driver = BrowserDriver.new settings
driver = browser_driver.prepare_browser
#driver.navigate.to 'https://google.com'


def parse_links(driver, url)

	#url = "https://www.wildberries.ru/catalog/knigi/hudozhestvennaya-literatura/"
	#url = "https://www.wildberries.ru/catalog/knigi/hudozhestvennaya-literatura?page=185"
	driver.get url
	#puts driver.find_elements(:css => ".class j-open-full-product-card")
	urls = []

	begin
		i=0
		while true do
			driver.find_elements(:class, "j-open-full-product-card").each do |el|
				urls << el.attribute("href")
			end
			next_button = driver.find_element(:class, "pagination-next")
			next_button.click
		end
	rescue Selenium::WebDriver::Error::NoSuchElementError => e
		puts "End"
	end

	puts urls.count
	#driver.quit

	#Crash
	#IO.write("urls.txt", urls.join("\n"))
	return urls	
end

def parse_book(driver, book_url)

	
	driver.get book_url
	#driver.find_element(:class, "noselect toggle-parameters j-toggle-add-options-detailed").click

	els = []
	image_link = driver.find_element(:class, "MagicZoomFullSizeImage").attribute("src")
	book_brand = driver.find_element(:class, "brand").text
	book_name = driver.find_element(:class, "name").text
	book_price = driver.find_element(:class, "final-cost").text

	els << image_link
	els << book_brand
	els << book_name
	els << book_price
	
	driver.find_elements(:css, "div.pp > span:nth-child(2)").each do |el|
		els << el.attribute("textContent").strip
		#el.displayed?
	end
	
	#element = driver.execute_script("return $('div.pp > span:nth-child(2)')[8]")
	#puts element.text
	return els

end 
file = File.new("./output.json", "a:UTF-8")


links = parse_links(driver, "https://www.wildberries.ru/catalog/knigi/hudozhestvennaya-literatura?page=180")
puts links.count
links.each do |l| 
	els = parse_book(driver, l)
	file.print(JSON.generate(els))
	file.print("\n")
end
#parse_book(driver, "https://www.wildberries.ru/catalog/9700025/detail.aspx?targetUrl=GP")




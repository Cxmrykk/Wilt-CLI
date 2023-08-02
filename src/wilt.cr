require "http/web_socket"
require "option_parser"
require "colorize"
require "json"
require "uri"

# Program version
VERSION = "v0.0.1-alpha"

# File & directory path
CONFIG_DIR_PATH = Path["~/.wilt"].expand(home: true)
CONFIG_FILE_PATH = Path["~/.wilt/config.json"].expand(home: true)
HISTORY_FILE_PATH = Path["~/.wilt/history.txt"].expand(home: true)

# Default values (Used for program reset or first start)
CONFIG_DEFAULTS = {
  "wss_url" => "wss://chat.petals.dev/api/v2/generate",
  "model" => "stabilityai/StableBeluga2",
  "stop_sequence" => "###",
  "extra_stop_sequences" => ["</s>"],
  "start_prompt" => "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the user's questions.###Assistant: Hi! How can I help you?###",
  "do_sample" => 1,
  "temperature" => 0.2,
  #"top_k" => 40,
  #"top_p" => 0.9,
  "max_length" => 2048,
  "max_new_tokens" => 1,
}

# Messages
LOADING_MESSAGE = "Loading... "
LOADING_SEQUENCE = ["🌑", "🌘", "🌗", "🌖", "🌕", "🌔", "🌓", "🌒"]

# Writes the JSON defaults to the config file path
def reset_config_file()
  begin
    File.write(CONFIG_FILE_PATH, CONFIG_DEFAULTS.to_json.to_s)
  rescue error
    STDERR.puts "ERROR writing \"#{CONFIG_FILE_PATH}\": #{error}"
    exit 1
  end
end

# Writes the JSON defaults to the history file path
def reset_history_file(contents = CONFIG_DEFAULTS["start_prompt"])
  begin
    File.write(HISTORY_FILE_PATH, contents)
  rescue error
    STDERR.puts "ERROR writing \"#{HISTORY_FILE_PATH}\": #{error}"
    exit 1
  end
end

# Make sure the configuration directory exists
def init_config_dir()
  if !Dir.exists?(CONFIG_DIR_PATH)
    begin
      Dir.mkdir(CONFIG_DIR_PATH)
    rescue error
      STDERR.puts "ERROR creating directory \"#{CONFIG_DIR_PATH}\": #{error}"
      exit 1
    end
  end
end

# Make sure the configuration file exists
def init_config_file()
  if !File.exists?(CONFIG_FILE_PATH)
    reset_config_file()
  end
end

# Make sure the history file exists
def init_history_file()
  if !File.exists?(HISTORY_FILE_PATH)
    reset_history_file()
  end
end

# Return the contents of the config file parsed as JSON
def get_config()
  init_config_dir()
  init_config_file()
  begin
    json = JSON.parse(File.read(CONFIG_FILE_PATH))
    
    # parse JSON string array (extra stop sequences)
    stop_sequences = [] of String
    index = 0

    loop do
      if json["extra_stop_sequences"][index]?.nil?
        break
      else
        stop_sequences.push(json["extra_stop_sequences"][index].as_s)
        index += 1
      end
    end

    # parse everything else using casting
    {
      wss_url: json["wss_url"].as_s,
      model: json["model"].as_s,
      stop_sequence: json["stop_sequence"].as_s,
      extra_stop_sequences: stop_sequences,
      start_prompt: json["start_prompt"].as_s,
      do_sample: json["do_sample"].as_i,
      temperature: json["temperature"].as_f,
      #top_k: json["top_k"].as_i,
      #top_p: json["top_p"].as_f,
      max_length: json["max_length"].as_i,
      max_new_tokens: json["max_new_tokens"].as_i,
    }

  rescue error
    STDERR.puts "ERROR parsing \"#{CONFIG_FILE_PATH}\": #{error}"
    exit 1
  end
end

# Return the string contents of the history file
def get_history()
  init_config_dir()
  init_history_file()
  begin
    File.read(HISTORY_FILE_PATH)
  rescue error
    STDERR.puts "ERROR reading \"#{HISTORY_FILE_PATH}\": #{error}"
    exit 1
  end
end

def format_output_stream(response)
  begin
    match_multiline = response.match(/```.*```/m)

    # find multiline matches (only use the first match)
    if !match_multiline.nil?
      start_pos = match_multiline.begin(0)
      end_pos = match_multiline.end(0)

      # rewrite the existing output lines
      lines = response.lines.reverse
      final = response.lines.size - 1

      # replace the existing output
      (0..final).each do |i|
        line = lines[i]
        print "\033[D" * line.size

        # place cursor at beginning of next line
        if i < final
          print "\033[A"
        end
      end

      # print the formatted response to output
      print response[0, start_pos]
      print response[start_pos, end_pos - start_pos].colorize.fore(:green).back(:black).bold()
      print response[end_pos, response.size - end_pos]

      # clear the response log
      return ""
    end

    match_singleline = response.match(/`(?:[^`\n]+)`/)

    if !match_singleline.nil?
      start_pos = match_singleline.begin(0)
      end_pos = match_singleline.end(0)

      # rewrite the existing output lines
      lines = response.lines.reverse
      final = response.lines.size - 1

      # replace the existing output
      (0..final).each do |i|
        line = lines[i]
        print "\033[D" * line.size

        # place cursor at beginning of next line
        if i < final
          print "\033[A"
        end
      end

      # print the formatted response to output
      print response[0, start_pos]
      print response[start_pos, end_pos - start_pos].colorize.fore(:light_green).back(:black).bold()
      print response[end_pos, response.size - end_pos]

      # clear the response log
      return ""
    end

    return response

  rescue error
    STDERR.puts "ERROR formatting output stream: #{error}"
    exit 1
  end
end

OptionParser.parse do |parser|
  parser.banner = "Usage: wilt [flag] | [prompt]"

  parser.on("-h", "--help", "Prints this message") do
    puts parser
    exit
  end

  parser.on("-v", "--version", "Prints the program version") do
    puts VERSION
    exit
  end

  parser.on("-c", "--config", "Prints the configuration file path") do
    puts CONFIG_FILE_PATH
    exit
  end

  parser.on("-l", "--history", "Prints the history file path") do
    puts HISTORY_FILE_PATH
    exit
  end

  parser.on("-f", "--forget", "Forgets the last conversation") do
    config = get_config()
    reset_history_file(config["start_prompt"])
    exit
  end

  parser.on("-r", "--reset-config", "Resets the configuration file") do
    reset_config_file()
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit 1
  end

  if ARGV.size == 0
    STDERR.puts "ERROR: No arguments specified."
    STDERR.puts parser
    exit
  end
end

config = get_config()
history = get_history()

# start websocket
init = false
prompt = "Human: #{ARGV.join(" ")}#{config["stop_sequence"]}Assistant:"
response = ""
response_log = ""

spawn do
  message = ""
  length = LOADING_SEQUENCE.size
  size = 0
  index = 0

  # send loading sequence until init is ok
  while !init
    if index >= length
      index = 0
    end

    message = LOADING_MESSAGE + LOADING_SEQUENCE[index]
    size = message.size
    index += 1

    print message
    print "\033[D" * (size + 1)
    sleep(1/length)
  end

  # erase the loading sequence
  print " " * size
  print "\033[D" * size
end

begin
  url = URI.parse(config["wss_url"])
  socket = HTTP::WebSocket.new(url)

  # handle received messages
  socket.on_message do |data|
    begin
      data = JSON.parse(data)

      # verify that data response was ok
      if !data["ok"]?.nil?
        if !data["ok"].as_bool

          # don't overlap existing output
          print "-\n"

          # exit with error output
          if !data["traceback"]?.nil?
            STDERR.puts "ERROR received from server with traceback:\n\n#{data["traceback"]}"
            exit 1
          else
            STDERR.puts "ERROR received from server with no traceback (response.ok was false)"
            exit 1
          end

        # response was ok, send prompt to server
        elsif !init
          init = true
          socket.send({
            "type" => "generate",
            "inputs" => "#{history}#{prompt}",
            "stop_sequence" => config["stop_sequence"],
            "extra_stop_sequences" => config["extra_stop_sequences"],
            "do_sample" => config["do_sample"],
            "temperature" => config["temperature"],
            #"top_k" => config["top_k"],
            #"top_p" => config["top_p"],
            "max_new_tokens" => config["max_new_tokens"],
          }.to_json)
        end
      end

    # send generate response to console
    if !data["outputs"]?.nil?
      outputs = data["outputs"].as_s

      # append new output to response + logs
      response += outputs
      response_log += outputs
      print outputs

      # slice the log message to prevent dupicate formatting
      response_log = format_output_stream(response_log)

      # close the socket when stop message received
      if !data["stop"]?.nil?
        if data["stop"].as_bool
          socket.close()

          # remove the trailer based on length of stop sequence
          all_stop_sequences = config["extra_stop_sequences"] + [config["stop_sequence"]]
          all_stop_sequences.each do |sequence|

            # verify which stop sequence was used
            if response.ends_with?(sequence)
              trailer = sequence.size

              # set response to the correct stop sequence
              response = response[0, response.size - trailer]
              response += config["stop_sequence"]

              # clear response output (remove trailer)
              print "\033[D" * trailer
              print " " * trailer
              break
            end
          end
        end
      end
    end

    rescue error
      STDERR.puts "ERROR receiving response from server: #{error}"
      exit 1
    end
  end

  # send the inference request
  socket.send({
    "type" => "open_inference_session",
    "model" => config["model"],
    "max_length" => config["max_length"],
  }.to_json)

  socket.run
rescue error
  STDERR.puts "ERROR initialising websocket: #{error}"
  exit 1
end

# end output stream
print "\n"

# update the history file
reset_history_file("#{history}#{prompt}#{response}")
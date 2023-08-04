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
  "input_prompt" => "Human: {args}{stop_sequence}Assistant:",
  "do_sample" => 1,
  "temperature" => 0.2,
  "top_p" => 0.9,
  "max_length" => 2048,
  "max_new_tokens" => 1,
}

def check_mkdir(path)
  if !Dir.exists?(path)
    begin
      Dir.mkdir(path)
    rescue error
      STDERR.puts "ERROR creating directory \"#{path}\": #{error}"
      exit 1
    end
  end
end

def mkfile(path, contents)
  begin
    File.write(path, contents)
  rescue error
    STDERR.puts "ERROR writing file \"#{path}\": #{error}"
    exit 1
  end
end

# Make sure the configuration file exists
def init_config_file()
  if !File.exists?(CONFIG_FILE_PATH)
    mkfile(CONFIG_FILE_PATH, CONFIG_DEFAULTS.to_json.to_s)
  end
end

# Make sure the history file exists
def init_history_file()
  if !File.exists?(HISTORY_FILE_PATH)
    mkfile(HISTORY_FILE_PATH, CONFIG_DEFAULTS["start_prompt"])
  end
end

# Return the contents of the config file parsed as JSON
def get_config()
  check_mkdir(CONFIG_DIR_PATH)
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
      input_prompt: json["input_prompt"].as_s,
      do_sample: json["do_sample"].as_i,
      temperature: json["temperature"].as_f,
      max_length: json["max_length"].as_i,
      max_new_tokens: json["max_new_tokens"].as_i,
      top_k: json["top_k"]?.try(&.as_i),
      top_p: json["top_p"]?.try(&.as_f)
    }

  rescue error
    STDERR.puts "ERROR parsing \"#{CONFIG_FILE_PATH}\": #{error}"
    exit 1
  end
end

# Return the string contents of the history file
def get_history()
  check_mkdir(CONFIG_DIR_PATH)
  init_history_file()
  begin
    File.read(HISTORY_FILE_PATH)
  rescue error
    STDERR.puts "ERROR reading \"#{HISTORY_FILE_PATH}\": #{error}"
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
    mkfile(HISTORY_FILE_PATH, config["start_prompt"])
    puts "Successfully reset \"#{HISTORY_FILE_PATH}\""
    exit
  end

  parser.on("-r", "--reset-config", "Resets the configuration file") do
    mkfile(CONFIG_FILE_PATH, CONFIG_DEFAULTS.to_json.to_s)
    puts "Successfully reset \"#{CONFIG_FILE_PATH}\""
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
response = ""
prompt = config["input_prompt"]
  .gsub("{args}", ARGV.join(" "))
  .gsub("{stop_sequence}", config["stop_sequence"])

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
            "top_k" => config["top_k"],
            "top_p" => config["top_p"],
            "max_new_tokens" => config["max_new_tokens"],
          }.to_json)
        end
      end

    # send generate response to console
    if !data["outputs"]?.nil?
      outputs = data["outputs"].as_s

      # append new output to response + logs
      response += outputs
      print outputs

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
mkfile(HISTORY_FILE_PATH, "#{history}#{prompt}#{response}")
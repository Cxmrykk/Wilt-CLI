require "http/web_socket"
require "json"
require "uri"

# File & directory path
CONFIG_DIR_PATH = Path["~/.wilt"].expand(home: true)
CONFIG_FILE_PATH = Path["~/.wilt/config.json"].expand(home: true)
HISTORY_FILE_PATH = Path["~/.wilt/history.txt"].expand(home: true)

# Default values (Used for program reset or first start)
CONFIG_DEFAULTS = {
  "wss-url" => "wss://chat.petals.dev/api/v2/generate",
  "model" => "meta-llama/Llama-2-70b-chat-hf",
  "max_length" => 1024,
  "max_new_tokens" => 1,
  "do_sample" => 0,
  "temperature" => 0.75,
  "stop_sequence" => "###"
}

HISTORY_DEFAULTS = "A chat between a curious human and an artificial intelligence assistant. " +
  "The assistant gives helpful, detailed, and polite answers to the user's questions.#{CONFIG_DEFAULTS["stop_sequence"]}" +
  "Assistant: Hi! how can I help you?#{CONFIG_DEFAULTS["stop_sequence"]}"

# Make sure the configuration directory exists
def init_config_dir()
  if !Dir.exists?(CONFIG_DIR_PATH)
    begin
      Dir.mkdir(CONFIG_DIR_PATH)
    rescue error
      puts "ERROR whilst creating directory \"#{CONFIG_DIR_PATH}\": #{error}"
      exit 1
    end
  end
end

# Make sure the configuration file exists
def init_config_file()
  if !File.exists?(CONFIG_FILE_PATH)
    begin
      File.write(CONFIG_FILE_PATH, CONFIG_DEFAULTS.to_json.to_s)
    rescue error
      puts "ERROR whilst writing \"#{CONFIG_FILE_PATH}\": #{error}"
      exit 1
    end
  end
end

# Make sure the history file exists
def init_history_file()
  if !File.exists?(HISTORY_FILE_PATH)
    begin
      File.write(HISTORY_FILE_PATH, HISTORY_DEFAULTS)
    rescue error
      puts "ERROR whilst writing \"#{HISTORY_FILE_PATH}\": #{error}"
      exit 1
    end
  end
end

# Return the contents of the config file parsed as JSON
def get_config_json()
  init_config_dir()
  init_config_file()
  begin
    JSON.parse File.read(CONFIG_FILE_PATH)
  rescue error
    puts "ERROR whilst parsing \"#{CONFIG_FILE_PATH}\": #{error}"
    exit 1
  end
end

# Return the string contents of the history file
def get_history_txt()
  init_config_dir()
  init_history_file()
  begin
    File.read(HISTORY_FILE_PATH)
  rescue error
    puts "ERROR whilst reading \"#{HISTORY_FILE_PATH}\": #{error}"
    exit 1
  end
end

config = get_config_json()
history = get_history_txt()

# inference = {
#   "type" => "open_inference_session",
#   "model" => "meta-llama/Llama-2-70b-chat-hf",
#   "max_length" => 1024
# }.to_json

# puts inference

# def get_generate(history)
#   {
#     "type" => "generate",
#     "stop_sequence" => "###",
#     "max_new_tokens" => 1,
#     "inputs" => history
#   }.to_json
# end

# url = URI.parse("wss://chat.petals.dev/api/v2/generate")
# socket = HTTP::WebSocket.new(url)
# history = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the user's questions.###Assistant: Hi! how can I help you?###"

# socket.on_message do |data|
#   data = JSON.parse(data)

#   begin
#     chunk = data["outputs"].to_s
#     history += chunk
#     print chunk
#   rescue
#     puts "message received:"
#     puts data
#   end
# end

# socket.send(inference)

# spawn do
#   while !socket.closed?
#     print "> "
#     user_input = gets
#     history += "Human: " + user_input.to_s + "### Assistant:"
#     processed_input = get_generate(history)

#     puts processed_input
#     socket.send(processed_input)
#   end
# end


# socket.run
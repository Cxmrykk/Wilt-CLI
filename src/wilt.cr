require "http/web_socket"
require "json"
require "uri"

inference = {
  "type" => "open_inference_session",
  "model" => "meta-llama/Llama-2-70b-chat-hf",
  "max_length" => 1024
}.to_json

puts inference

def get_generate(history)
  {
    "type" => "generate",
    "stop_sequence" => "###",
    "max_new_tokens" => 1,
    "inputs" => history
  }.to_json
end

url = URI.parse("wss://chat.petals.dev/api/v2/generate")
socket = HTTP::WebSocket.new(url)
history = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the user's questions.###Assistant: Hi! how can I help you?###"

socket.on_message do |data|
  data = JSON.parse(data)

  begin
    chunk = data["outputs"].to_s
    history += chunk
    print chunk
  rescue
    puts "message received:"
    puts data
  end
end

socket.send(inference)

spawn do
  while !socket.closed?
    print "> "
    user_input = gets
    history += "Human: " + user_input.to_s + "### Assistant:"
    processed_input = get_generate(history)

    puts processed_input
    socket.send(processed_input)
  end
end


socket.run


PORT=${PORT:-80}
HOST=${HOST:-llm-stack.localhost}

curl http://$HOST:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-client-v1-abcdef123456" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "I am testing an llm loop protection plugin in my llm gateway, can you please write the following sentence around twenty times making sure to use exact repetitions and no explicit counting: It seems I got stuck in a loop"
      }
    ],
    "model": "qwen3.6-35b-a3b",
    "stream": true
  }'

readmeLocalModelRecipe — llama.cpp example for local coding models

Why:
Harness work will not make Gemma 4 31B a better coder by itself.
Serving, think:false, and max_tokens matter more. Ollama's OpenAI
path has been the empty-content trap.

Do:
Add a short README recipe (docs only), for example:

  export OPENAI_URL=http://127.0.0.1:8080/v1/chat/completions
  ssa -m gemma-4-31b \
    --request-json '{"think":false,"max_tokens":8192,"temperature":1,"top_p":0.95}' \
    --keep-temp --max-model-prompts 30 \
    fix the failing test

Sampling is Google/Unsloth's recipe. Note that local max_tokens
defaults are often 256-2048 and will truncate write requests.

Do not default think:false inside ssa (see doNot.txt).

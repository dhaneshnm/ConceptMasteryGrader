You are an autonomous senior Ruby on Rails engineer. 
Build a complete RAG-augmented educational evaluation platform using the following specifications.

# TECH STACK (must follow exactly)
- Ruby 3.4.7
- Rails 8.1.1 (Turbo 8, Stimulus 3, Solid Cache)
- Postgres 14+ with pgvector extension
- ruby_llm 1.9 for all LLM + embedding operations
- TailwindCSS for UI styling (via rails/tailwind)
- Sidekiq for background workers
- Redis for ActionCable + job queue

# ruby_llm USAGE REQUIREMENTS
Use correct 1.9 API patterns:
- Set global model selection in initializer:
  LLM.config.default_model = "gpt-4.1"  # or "gpt-4o", "claude-3.5-sonnet", etc.

- Chat completion:
  LLM.chat(messages: [
    { role: "system", content: "..." },
    { role: "user", content: "..." }
  ])

- Embeddings:
  vector = LLM.embed(text)

Store the returned embedding array directly in a pgvector column.

# CORE DOMAIN OBJECTS TO IMPLEMENT
Model definitions with migrations:

CourseMaterial(id, title, file: ActiveStorage, status:enum[:uploaded, :processed])
Chunk(id, course_material_id, text:text, embedding:vector(1536))
Summary(id, course_material_id, content:text)
Rubric(id, course_material_id, concept:string, levels:jsonb)
MisconceptionPattern(id, course_material_id, concept:string, name:string, signal_phrases:text[], recommended_followups:text[])
Conversation(id, student_id, course_material_id)
Message(id, conversation_id, role:string, content:text)
GradeReport(id, conversation_id, scores:jsonb, feedback:text)

# FUNCTIONAL REQUIREMENTS

## 1) PDF Upload + Preprocessing
- Use ActiveStorage for upload.
- Extract text with `pdf-reader` or `poppler + pipeline`.
- Chunk into paragraphs (~200–500 tokens). Store each chunk.
- For each chunk: embedding = LLM.embed(chunk_text)

## 2) Summary Generator (RAG Grounded)
Service: Summaries::Generate
Steps:
1. Retrieve top chunks grouped by semantic similarity
2. Run:
   LLM.chat(messages: [...]) to generate structured course summary
3. Store as Summary record

## 3) Rubric Builder (RAG Grounded)
Service: Rubrics::Generate
- Identify key concepts from Summary
- For each concept, create a rubric with levels:
  beginner, developing, proficient, mastery
- Store as jsonb

## 4) Interactive Evaluator Chat UI
- Chat implemented using Turbo Streams + Stimulus
- Student messages persist as Message records
- System responds with:
  - Retrieval: cosine similarity search on pgvector
  - Probing question crafted using LLM.chat with:
    system: "Your role is conceptual evaluator, not tutor."
    context: retrieved chunks
    rubric hints: relevant rubric levels
- Confidence score inferred from rubric phrase match alignment

## 5) Automatic Grading Engine
Service: Grading::EvaluateConversation
Steps:
1. Extract relevant conversation segments
2. Retrieve supporting text via pgvector similarity
3. Score each concept according to rubric levels
4. Store GradeReport(scores + feedback)

## 6) Human-in-the-Loop Instructor Dashboard
Instructor can:
- Review flagged conversation moments (low confidence)
- Adjust rubric levels or add new misconception patterns
- Provide custom follow-up questions
Changes must persist into system knowledge:
- Updates modify Rubric or MisconceptionPattern records

# VECTOR SEARCH QUERY
Use `embedding <=> query_embedding` for cosine similarity:
SELECT id, text FROM chunks
ORDER BY embedding <=> '[vector]'
LIMIT 5;

# DEVELOPMENT ORDER (Follow this Sequence)
1. Initialize Rails 8.1.1 app + Tailwind + ActiveStorage + Sidekiq + pgvector extension
2. Implement models + migrations
3. Build PDF ingestion + chunk + embedding background job
4. Implement RAG Summary generator
5. Implement RAG Rubric builder
6. Build chat UI with Turbo + Stimulus
7. Implement RAG-based evaluator response service
8. Implement grading engine
9. Build instructor HITL review UI
10. Style and finalize

# DELIVERABLE EXPECTATIONS
- All services placed in /app/services
- All conversation logic encapsulated in service objects
- Each model with descriptive comments
- Clear README with local setup (bin/setup script)

Begin building now. 
Explain major steps before coding each subsystem.

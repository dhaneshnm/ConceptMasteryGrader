# Concept Mastery Grader - RAG-Augmented Educational Evaluation Platform

A sophisticated AI-powered educational assessment system that combines Retrieval-Augmented Generation (RAG) with interactive Socratic dialogue for evaluating student understanding.

## 🎯 Overview

Concept Mastery Grader transforms traditional educational assessment by using advanced AI to engage students in meaningful conversations while automatically evaluating their conceptual understanding. The platform processes course materials, generates dynamic rubrics, and provides real-time feedback through intelligent dialogue.

## ✨ Key Features

### 🤖 AI-Powered Assessment Engine
- **RAG-based Evaluation**: Uses semantic similarity search with pgvector to retrieve relevant context
- **Socratic Dialogue**: Generates probing questions to assess deep understanding
- **Automatic Grading**: Evaluates responses against dynamically generated rubrics
- **Real-time Feedback**: Provides immediate, contextual feedback during conversations

### 📚 Intelligent Content Processing
- **PDF Ingestion**: Automated text extraction and semantic chunking
- **Summary Generation**: AI-powered course material summarization
- **Rubric Creation**: Automatic generation of assessment rubrics from content
- **Misconception Detection**: Identifies and tracks common student misconceptions

### 💬 Interactive Learning Interface
- **Real-time Chat**: Turbo Streams-powered conversation interface
- **Adaptive Questioning**: AI adjusts questions based on student responses
- **Progress Tracking**: Visual progress indicators and concept mastery tracking
- **Engagement Analytics**: Detailed insights into student engagement patterns

### 👩‍🏫 Instructor Dashboard
- **Conversation Management**: Review and analyze all student interactions
- **Performance Analytics**: Comprehensive reporting and trend analysis
- **Rubric Management**: Edit and refine assessment criteria
- **Misconception Patterns**: Track and address common learning gaps

## 🏗️ Technology Stack

- **Backend**: Rails 8.1.1 with Turbo Streams and Stimulus
- **Database**: PostgreSQL 14+ with pgvector extension for vector similarity search
- **AI/LLM**: ruby_llm 1.9 with support for OpenAI, Anthropic, and Google AI
- **Background Jobs**: Sidekiq with Redis for queue management  
- **Styling**: TailwindCSS with responsive design
- **File Storage**: ActiveStorage with cloud storage support

## 🔄 System Architecture & Workflow

```mermaid
graph TB
    %% User Interface Layer
    subgraph "Frontend Layer"
        UI[Student Chat Interface]
        ID[Instructor Dashboard]
        UI2[Real-time Updates via Turbo Streams]
    end

    %% Application Layer
    subgraph "Rails Application Layer"
        subgraph "Controllers"
            CC[ConversationsController]
            MC[MessagesController]
            CMC[CourseMaterialsController]
            IDC[Instructor::DashboardController]
        end
        
        subgraph "Models"
            CM[CourseMaterial]
            CONV[Conversation]
            MSG[Message]
            CHK[Chunk + Embeddings]
            RUB[Rubric]
            GR[GradeReport]
        end
    end

    %% Service Layer
    subgraph "AI Services Layer"
        subgraph "Document Processing"
            EXT[Documents::ExtractText]
            CHUNK[Documents::GenerateChunks] 
            EMB[Documents::GenerateEmbeddings]
        end
        
        subgraph "AI Generation"
            SUM[Summaries::Generate]
            RUBGEN[Rubrics::Generate]
            EVAL[Evaluator::ResponseGenerator]
            GRADE[Grading::EvaluateConversation]
        end
    end

    %% Background Jobs
    subgraph "Background Processing (Sidekiq)"
        DIG[DocumentIngestionJob]
        SGJ[SummaryGenerationJob]
        RGJ[RubricGenerationJob]
        ERJ[EvaluatorResponseJob]
        CEJ[ConversationEvaluationJob]
    end

    %% External Services
    subgraph "External Services"
        LLM[LLM Providers<br/>OpenAI/Anthropic/Google]
        STORAGE[File Storage<br/>ActiveStorage/S3]
    end

    %% Database Layer
    subgraph "Data Layer"
        PG[(PostgreSQL + pgvector<br/>Vector Similarity Search)]
        REDIS[(Redis<br/>Cache + Jobs)]
    end

    %% Workflow Connections
    
    %% 1. Document Upload Workflow
    UI --> CMC
    CMC --> CM
    CM --> STORAGE
    CM --> DIG
    DIG --> EXT
    EXT --> CHUNK
    CHUNK --> EMB
    EMB --> LLM
    LLM --> CHK
    CHK --> PG
    
    %% 2. Summary & Rubric Generation
    DIG --> SGJ
    DIG --> RGJ
    SGJ --> SUM
    RGJ --> RUBGEN
    SUM --> LLM
    RUBGEN --> LLM
    
    %% 3. Interactive Conversation Workflow
    UI --> CC
    CC --> CONV
    UI --> MC
    MC --> MSG
    MSG --> ERJ
    ERJ --> EVAL
    EVAL --> PG
    EVAL --> LLM
    LLM --> MSG
    MSG --> UI2
    
    %% 4. Evaluation & Grading Workflow
    MC --> CEJ
    CEJ --> GRADE
    GRADE --> PG
    GRADE --> LLM
    GRADE --> GR
    GR --> ID
    
    %% 5. Instructor Analytics
    ID --> IDC
    IDC --> PG
    IDC --> REDIS
    
    %% Redis connections
    REDIS --> DIG
    REDIS --> SGJ
    REDIS --> RGJ
    REDIS --> ERJ
    REDIS --> CEJ

    %% Styling
    classDef frontend fill:#e1f5fe
    classDef rails fill:#f3e5f5
    classDef services fill:#e8f5e8
    classDef jobs fill:#fff3e0
    classDef external fill:#ffebee
    classDef data fill:#f1f8e9
    
    class UI,ID,UI2 frontend
    class CC,MC,CMC,IDC,CM,CONV,MSG,CHK,RUB,GR rails
    class EXT,CHUNK,EMB,SUM,RUBGEN,EVAL,GRADE services
    class DIG,SGJ,RGJ,ERJ,CEJ jobs
    class LLM,STORAGE external
    class PG,REDIS data
```

### 📋 Workflow Breakdown

#### 1. **Document Ingestion Pipeline**
```
PDF Upload → Text Extraction → Semantic Chunking → Embedding Generation → Vector Storage
     ↓              ↓                ↓                    ↓                  ↓
ActiveStorage → pdf-reader → Smart Segmentation → LLM Embeddings → pgvector Database
```

#### 2. **AI Content Generation**
```
Course Material → Content Analysis → LLM Processing → Generated Content
      ↓               ↓                 ↓                 ↓
   Raw Text → Concept Extraction → Prompt Engineering → Summaries/Rubrics
```

#### 3. **Real-time Conversation Flow**
```
Student Message → Context Retrieval → AI Response Generation → Real-time Update
      ↓               ↓                      ↓                      ↓
   User Input → Vector Similarity → RAG + LLM Processing → Turbo Streams
```

#### 4. **Automatic Assessment Pipeline**
```
Conversation → Content Analysis → Rubric Evaluation → Grade Report Generation
     ↓              ↓                  ↓                    ↓
  Chat History → Pattern Recognition → AI Scoring → Detailed Feedback
```

#### 5. **Instructor Analytics Dashboard**
```
Raw Data → Statistical Analysis → Performance Metrics → Visual Dashboard
    ↓            ↓                     ↓                  ↓
Database → Aggregation Queries → Trend Analysis → Real-time Charts
```

## 🚀 Quick Start

### Prerequisites
- Ruby 3.4.3+
- Node.js 18+
- PostgreSQL 14+ with pgvector
- Redis 6+
- OpenAI API key

### Installation

1. **Clone and Setup**
```bash
git clone https://github.com/your-org/grader-i2.git
cd grader-i2
bundle install
npm install
```

2. **Environment Configuration**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Database Setup**
```bash
rails db:setup
rails db:migrate
```

4. **Start Services**
```bash
# Start Rails server
rails server

# Start Sidekiq (in another terminal)
bundle exec sidekiq
```

5. **Access Application**
- Web Interface: http://localhost:3000
- Instructor Dashboard: http://localhost:3000/instructor/dashboard

## 📈 Complete Implementation

This project represents a fully implemented RAG-augmented educational evaluation platform with:

✅ **Rails 8.1.1 Application** with modern architecture
✅ **Complete Domain Models** with proper associations and validations
✅ **PDF Processing Pipeline** with chunking and embedding generation
✅ **RAG Summary Generator** for course material analysis
✅ **RAG Rubric Builder** for automatic assessment criteria
✅ **Interactive Chat Interface** with Turbo Streams and Stimulus
✅ **RAG-based Evaluator Service** with semantic similarity search
✅ **Automatic Grading Engine** with detailed feedback reports
✅ **Instructor Dashboard** for comprehensive course management
✅ **Production Deployment Configuration** with Docker and deployment guides

## 🔒 Security & Performance

- **Vector Similarity Search**: Sub-100ms queries with pgvector
- **Real-time Updates**: Turbo Streams for instant UI updates
- **Background Processing**: Scalable job processing with Sidekiq
- **Production Ready**: Complete deployment configuration and monitoring

## 📞 Support

For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)

Built with Rails 8.1.1, ruby_llm 1.9, and modern web technologies.

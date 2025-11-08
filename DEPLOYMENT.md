# Concept Mastery Grader - Production Deployment Guide

This guide covers deploying the Concept Mastery Grader RAG-augmented educational evaluation platform to production.

## 🏗️ Architecture Overview

The application consists of:
- **Rails 8.1.1** web application with Turbo Streams and Stimulus
- **PostgreSQL with pgvector** for vector similarity search
- **Redis** for caching and Sidekiq job queuing
- **Sidekiq** for background job processing
- **ruby_llm 1.9** for AI/LLM integration
- **TailwindCSS** for styling

## 📋 Prerequisites

- Ruby 3.4.3+
- Node.js 18+
- PostgreSQL 14+ with pgvector extension
- Redis 6+
- OpenAI API key (or other LLM provider)

## 🔧 Environment Configuration

### Required Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/grader_i2_production

# Redis 
REDIS_URL=redis://localhost:6379/0

# Rails
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_base_here
RAILS_MASTER_KEY=your_master_key_here

# LLM Provider
OPENAI_API_KEY=your_openai_api_key_here

# Application
APP_HOST=your-domain.com
FORCE_SSL=true
```

### Generate Secrets

```bash
# Generate SECRET_KEY_BASE
rails secret

# Generate RAILS_MASTER_KEY
rails credentials:edit
```

## 🚀 Deployment Options

### Option 1: Heroku Deployment

1. **Create Heroku App**
```bash
heroku create your-app-name
heroku addons:create heroku-postgresql:standard-0
heroku addons:create heroku-redis:premium-0
```

2. **Configure Environment Variables**
```bash
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set RAILS_MASTER_KEY=your_master_key
heroku config:set OPENAI_API_KEY=your_openai_key
heroku config:set APP_HOST=your-app-name.herokuapp.com
```

3. **Deploy**
```bash
git push heroku main
heroku run rails db:migrate
heroku ps:scale worker=1
```

### Option 2: Docker Deployment

1. **Build and Run with Docker Compose**
```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with your values

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Setup database
docker-compose exec web rails db:setup
```

2. **Initialize Database**
```bash
docker-compose exec web rails db:migrate
docker-compose exec web rails db:seed
```

### Option 3: Traditional VPS Deployment

1. **Server Setup (Ubuntu 22.04)**
```bash
# Install dependencies
sudo apt update
sudo apt install -y postgresql postgresql-contrib redis-server nginx

# Install PostgreSQL pgvector extension
sudo apt install postgresql-14-pgvector

# Install Ruby (via rbenv/rvm)
# Install Node.js (via nvm)
```

2. **Application Setup**
```bash
# Clone repository
git clone https://github.com/your-org/grader-i2.git
cd grader-i2

# Install dependencies
bundle install --deployment --without development test
npm ci --only=production

# Configure environment
cp .env.example .env
# Edit .env file

# Setup database
rails db:setup RAILS_ENV=production
rails db:migrate RAILS_ENV=production

# Precompile assets
rails assets:precompile RAILS_ENV=production
```

3. **Process Management with Systemd**
```bash
# Copy service files
sudo cp deploy/systemd/grader-i2-web.service /etc/systemd/system/
sudo cp deploy/systemd/grader-i2-worker.service /etc/systemd/system/

# Enable and start services
sudo systemctl enable grader-i2-web grader-i2-worker
sudo systemctl start grader-i2-web grader-i2-worker
```

## 📊 Background Jobs Setup

The application uses Sidekiq for background processing:

- **Document ingestion** (PDF processing, chunking, embedding generation)
- **AI response generation** (RAG-based evaluator responses)
- **Conversation evaluation** (automatic grading)
- **Summary and rubric generation**

### Sidekiq Configuration

```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - critical
  - default
  - low

:scheduler:
  cleanup_old_jobs:
    every: '1h'
    class: CleanupJobsWorker
```

## 🔒 Security Considerations

### SSL/TLS Configuration
- Force SSL in production (`FORCE_SSL=true`)
- Use proper SSL certificates (Let's Encrypt recommended)
- Configure secure headers

### Database Security
- Use strong passwords
- Restrict database access to application servers only
- Enable connection encryption
- Regular backups

### API Key Management
- Store API keys in environment variables or encrypted credentials
- Rotate keys regularly
- Monitor API usage and costs

### File Upload Security
- Validate file types (PDF only)
- Scan uploaded files for malware
- Use cloud storage (S3) in production
- Implement file size limits

## 📈 Monitoring and Logging

### Application Monitoring
```bash
# Install monitoring tools
gem install newrelic_rpm  # For application performance
gem install sentry-ruby   # For error tracking
```

### Log Management
```bash
# Configure structured logging
config.log_formatter = ::Logger::Formatter.new
config.log_level = :info

# Use external logging service (Papertrail, Loggly)
```

### Health Checks
The application includes built-in health checks:
- `GET /up` - Basic application health
- `GET /health/detailed` - Detailed system status

## 🗄️ Database Management

### Backups
```bash
# Automated backup script
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
psql $DATABASE_URL < backup_file.sql
```

### Migrations
```bash
# Run migrations
rails db:migrate RAILS_ENV=production

# Rollback if needed
rails db:rollback RAILS_ENV=production
```

### pgvector Maintenance
```bash
# Optimize vector indexes
psql $DATABASE_URL -c "REINDEX INDEX CONCURRENTLY chunks_embedding_idx;"

# Monitor index usage
psql $DATABASE_URL -c "SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch FROM pg_stat_user_indexes WHERE schemaname = 'public';"
```

## 🔧 Performance Optimization

### Database Optimization
- Index optimization for frequent queries
- Connection pooling configuration
- Query optimization and monitoring

### Caching Strategy
- Redis caching for expensive operations
- Fragment caching for view components
- CDN for static assets

### Background Job Optimization
- Job prioritization and queue management
- Monitoring job performance and failures
- Rate limiting for external API calls

## 🚨 Troubleshooting

### Common Issues

1. **pgvector Extension Missing**
```bash
sudo apt install postgresql-14-pgvector
psql $DATABASE_URL -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

2. **Sidekiq Jobs Failing**
```bash
# Check Sidekiq logs
tail -f log/sidekiq.log

# Restart Sidekiq
sudo systemctl restart grader-i2-worker
```

3. **Memory Issues**
```bash
# Monitor memory usage
free -h
htop

# Optimize Ruby memory settings
export RUBY_GC_MALLOC_LIMIT=90000000
export RUBY_GC_HEAP_INIT_SLOTS=750000
```

4. **SSL Certificate Issues**
```bash
# Check certificate status
openssl s_client -connect your-domain.com:443

# Renew Let's Encrypt certificate
sudo certbot renew
```

## 📞 Support and Maintenance

### Regular Tasks
- Monitor error rates and performance metrics
- Review and rotate API keys
- Update dependencies and security patches
- Database maintenance and cleanup
- Backup verification and testing

### Scaling Considerations
- Horizontal scaling with load balancers
- Database read replicas for high traffic
- Multiple Sidekiq workers for job processing
- CDN integration for global performance

---

## 🎯 Quick Deploy Checklist

- [ ] Environment variables configured
- [ ] Database setup with pgvector
- [ ] Redis running and accessible  
- [ ] SSL certificates configured
- [ ] Background workers running
- [ ] Monitoring and logging setup
- [ ] Backups configured
- [ ] Health checks passing
- [ ] Security headers configured
- [ ] Performance monitoring active

For additional support, refer to the application documentation or contact the development team.
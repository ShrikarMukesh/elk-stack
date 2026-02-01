# ELK Stack Setup & Troubleshooting Guide


**Project**: Elevens Bank Microservices  
**Purpose**: Centralized logging and visualization using Elasticsearch, Logstash, and Kibana

---

## 📋 Table of Contents

1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [What Was Fixed](#what-was-fixed)
4. [Sample Data Added](#sample-data-added)
5. [Kibana Setup Instructions](#kibana-setup-instructions)
6. [Useful Commands](#useful-commands)
7. [Troubleshooting](#troubleshooting)

---

## 🔍 Problem Statement

### Initial Issue
- **Error**: "The index pattern you entered doesn't match any data streams, indices, or index aliases"
- **Root Cause**: No data existed in Elasticsearch
- **Why**: Logstash was misconfigured and couldn't parse microservices logs

### Verification
```bash
curl http://localhost:9200/_cat/indices
# Result: Empty (no indices found)
```

---

## ✅ Solution Overview

### ELK Data Flow
```
Microservices → Generate JSON Logs → Logstash (JSON codec) → Elasticsearch (Index) → Kibana (Visualize)
```

### Key Components
| Component | Port | Purpose | Status |
|-----------|------|---------|--------|
| **Elasticsearch** | 9200 | Data storage & indexing | ✅ Running |
| **Kibana** | 5601 | Visualization & UI | ✅ Running |
| **Logstash** | - | Log processing pipeline | ✅ Running (Fixed) |

---

## 🔧 What Was Fixed

### Issue 1: Logstash Configuration - Wrong Log Format

**Problem**: Microservices generate **JSON-formatted logs**, but Logstash was configured to parse **plain text logs**.

**Evidence**:
```bash
docker logs elk-logstash-1 --tail 50
# Showed: "_grokparsefailure" tags
```

**Solution**: Updated `pipeline/logstash.conf`

#### Before (Incorrect)
```conf
input {
  file {
    path => "/logs/logs/*.log"
    start_position => "beginning"
    sincedb_path => "/dev/null"
    mode => "read"
    # ❌ Missing codec - defaults to plain text
  }
}

filter {
  # ❌ Trying to parse plain text format
  grok {
    match => { "message" => "%{TIMESTAMP_ISO8601:timestamp}..." }
  }
}
```

#### After (Correct)
```conf
input {
  file {
    path => "/logs/logs/*.log"
    start_position => "beginning"
    sincedb_path => "/dev/null"
    mode => "read"
    file_completed_action => "log"
    file_completed_log_path => "/dev/null"
    codec => "json"  # ✅ Parse JSON format!
  }
}

filter {
  # Extract service name from filename
  grok {
    match => {
      "path" => "/logs/logs/(?<service_name>[^.]+).*\.log"
    }
  }

  # Your logs already have @timestamp from JSON
  if [@timestamp] {
    date {
      match => ["@timestamp", "ISO8601"]
      target => "@timestamp"
    }
  }

  # Add environment tag
  mutate {
    add_field => { "environment" => "local" }
  }

  # Rename fields for clarity
  mutate {
    rename => {
      "message" => "log_message"
      "logger_name" => "logger"
      "thread_name" => "thread"
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "elevens-bank-logs-%{service_name}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
```

**Key Changes**:
1. ✅ Added `codec => "json"` in input section
2. ✅ Removed unnecessary grok pattern for plain text parsing
3. ✅ Simplified filter to work with JSON fields
4. ✅ Added field renaming for better clarity

### Restart Logstash
```bash
cd /home/shrikar/Bank/elevens-bank/elk
docker-compose restart logstash
```

---

## 📊 Sample Data Added

To help you learn Kibana immediately, I added 20 sample banking transactions.

### Sample Data Script
```bash
# Add sample banking transactions
for i in {1..20}; do
  curl -X POST "http://localhost:9200/banking-transactions/_doc" \
    -H 'Content-Type: application/json' -d"{
    \"timestamp\": \"$(date -u -d "$i minutes ago" +%Y-%m-%dT%H:%M:%S)\",
    \"customer_id\": \"CUST00$((RANDOM % 5 + 1))\",
    \"account_number\": \"ACC$((RANDOM % 10000 + 10000))\",
    \"transaction_type\": \"$(shuf -n1 -e DEPOSIT WITHDRAWAL TRANSFER)\",
    \"amount\": $((RANDOM % 5000 + 100)),
    \"balance\": $((RANDOM % 50000 + 5000)),
    \"service\": \"$(shuf -n1 -e account-service transaction-service loan-service)\",
    \"status\": \"$(shuf -n1 -e SUCCESS SUCCESS SUCCESS FAILED)\"
  }"
done
```

### Verify Data
```bash
curl -s "http://localhost:9200/_cat/indices?v"
# Expected output:
# yellow open banking-transactions ... 20 docs
```

### Sample Document Structure
```json
{
  "timestamp": "2026-01-11T16:00:00",
  "customer_id": "CUST001",
  "account_number": "ACC12345",
  "transaction_type": "DEPOSIT",
  "amount": 5000,
  "balance": 15000,
  "service": "account-service",
  "status": "SUCCESS"
}
```

---

## 🎨 Kibana Setup Instructions

### Step 1: Access Kibana
Open your browser and navigate to: **http://localhost:5601**

### Step 2: Create Data View for Sample Data

1. Click **hamburger menu (☰)** → **Stack Management** → **Data Views**
2. Click **"Create data view"**
3. Fill in the form:
   - **Name**: `Banking Transactions`
   - **Index pattern**: `banking-transactions*`
   - **Timestamp field**: Select `timestamp` from dropdown
4. Click **"Save data view to Kibana"**

### Step 3: Explore Data in Discover

1. Go to **hamburger menu (☰)** → **Discover**
2. Select **"Banking Transactions"** from top-left dropdown
3. You should see all 20 sample transactions
4. **Adjust time range**: Click time picker (top-right) → Select "Last 15 years" to see all data

### Step 4: Create Your First Visualization

#### Option A: Pie Chart - Transaction Types Distribution

1. Go to **Dashboard** → **Create dashboard**
2. Click **"Create visualization"**
3. Select **"Pie"** chart type
4. Configure:
   - **Data View**: Banking Transactions
   - **Slice by**: `transaction_type.keyword`
   - **Metric**: Count
5. Click **"Save and return"**
6. Name your dashboard: "Banking Overview"

#### Option B: Bar Chart - Transactions by Service

1. Click **"Create visualization"** again
2. Select **"Bar vertical"**
3. Configure:
   - **Horizontal axis**: `service.keyword`
   - **Vertical axis**: Count
   - **Break down by**: `status.keyword`
4. Click **"Save and return"**

#### Option C: Metric - Average Transaction Amount

1. Click **"Create visualization"**
2. Select **"Metric"**
3. Configure:
   - **Metric**: Average of `amount`
4. Click **"Save and return"**

### Step 5: Query Data with KQL (Kibana Query Language)

In the Discover search bar, try these queries:

```kql
# Find all failed transactions
status: "FAILED"

# Find deposits over 3000
transaction_type: "DEPOSIT" AND amount > 3000

# Find transactions for specific customer
customer_id: "CUST001"

# Find transactions from account-service
service: "account-service"

# Combine multiple conditions
service: "transaction-service" AND status: "SUCCESS"
```

---

## 🔄 For Microservices Logs

### Creating Data View for Microservices

Once your microservices are running and generating logs:

1. **Verify indices exist**:
   ```bash
   curl "http://localhost:9200/_cat/indices?v" | grep elevens-bank
   ```

2. **Expected indices** (after logs are generated):
   - `elevens-bank-logs-account-service-2026.01.11`
   - `elevens-bank-logs-auth-service-2026.01.11`
   - `elevens-bank-logs-discovery-service-2026.01.11`
   - `elevens-bank-logs-transaction-service-2026.01.11`
   - etc.

3. **Create Data View in Kibana**:
   - **Name**: `Elevens Bank Logs`
   - **Index pattern**: `elevens-bank-logs-*`
   - **Timestamp field**: `@timestamp`

4. **Available Fields** (from JSON logs):
   - `@timestamp` - When the log was created
   - `level` - Log level (INFO, WARN, ERROR, DEBUG)
   - `logger` - Logger name (class name)
   - `thread` - Thread name
   - `log_message` - Actual log message
   - `service_name` - Extracted service name
   - `environment` - "local"
   - `stack_trace` - For ERROR logs

### Example Queries for Microservices Logs

```kql
# Find all ERROR logs
level: "ERROR"

# Find logs from specific service
service_name: "account-service"

# Find specific class logs
logger: *CustomerController*

# Combine filters
service_name: "auth-service" AND level: "ERROR"
```

---

## 🛠️ Useful Commands

### Check ELK Stack Status
```bash
cd /home/shrikar/Bank/elevens-bank/elk
docker-compose ps
```

### View Logs from Containers
```bash
# Elasticsearch logs
docker logs elk-elasticsearch-1 --tail 100

# Logstash logs (check for processing errors)
docker logs elk-logstash-1 --tail 100

# Kibana logs
docker logs elk-kibana-1 --tail 100
```

### Check Elasticsearch Health
```bash
# Cluster health
curl http://localhost:9200/_cluster/health?pretty

# List all indices
curl http://localhost:9200/_cat/indices?v

# Count documents in an index
curl http://localhost:9200/banking-transactions/_count?pretty

# Search specific index
curl http://localhost:9200/banking-transactions/_search?pretty
```

### Restart Services
```bash
cd /home/shrikar/Bank/elevens-bank/elk

# Restart all
docker-compose restart

# Restart specific service
docker-compose restart logstash
docker-compose restart elasticsearch
docker-compose restart kibana
```

### Delete and Recreate (If Needed)
```bash
cd /home/shrikar/Bank/elevens-bank/elk

# Stop all services
docker-compose down

# Remove volumes (WARNING: This deletes all data!)
docker-compose down -v

# Start fresh
docker-compose up -d
```

### Delete Sample Data (If Needed)
```bash
# Delete the sample banking index
curl -X DELETE http://localhost:9200/banking-transactions

# Verify deletion
curl http://localhost:9200/_cat/indices?v
```

---

## 🆘 Troubleshooting

### Issue: "No results match your search criteria" in Kibana Discover

**Solutions**:
1. **Adjust time range**: Click time picker → Select "Last 15 years"
2. **Check data view**: Ensure correct data view is selected (top-left)
3. **Verify data exists**:
   ```bash
   curl http://localhost:9200/banking-transactions/_count?pretty
   ```

### Issue: Logstash shows "_grokparsefailure"

**Cause**: Log format doesn't match the grok pattern

**Solution**: 
- Verify `codec => "json"` is in the input section of `logstash.conf`
- Check if your logs are actually JSON format:
  ```bash
  head -5 /home/shrikar/Bank/elevens-bank/logs/account-service.log
  ```

### Issue: No microservices indices appearing

**Checklist**:
1. ✅ Are microservices running?
2. ✅ Are they generating logs?
   ```bash
   ls -lh /home/shrikar/Bank/elevens-bank/logs/*.log
   ```
3. ✅ Is Logstash running?
   ```bash
   docker ps | grep logstash
   ```
4. ✅ Check Logstash logs for errors:
   ```bash
   docker logs elk-logstash-1 --tail 50
   ```

### Issue: Elasticsearch health is YELLOW

**This is NORMAL for single-node clusters!**

- Yellow = Primary shards are allocated, but replicas are not
- Since you have `discovery.type=single-node`, there's no second node for replicas
- **No action needed** - this is expected in development

### Issue: Elasticsearch health is RED

```bash
# Check cluster health details
curl http://localhost:9200/_cluster/health?pretty

# Restart Elasticsearch
cd /home/shrikar/Bank/elevens-bank/elk
docker-compose restart elasticsearch

# Check logs
docker logs elk-elasticsearch-1 --tail 100
```

---

## 📚 Additional Resources

### Official Documentation
- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Logstash Guide](https://www.elastic.co/guide/en/logstash/current/index.html)

### Learning Resources
- [KQL (Kibana Query Language)](https://www.elastic.co/guide/en/kibana/current/kuery-query.html)
- [Grok Patterns](https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html)
- [Elasticsearch Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html)

### Quick Reference
- **Elasticsearch API**: http://localhost:9200
- **Kibana UI**: http://localhost:5601
- **Logs Location**: `/home/shrikar/Bank/elevens-bank/logs/`
- **Logstash Config**: `/home/shrikar/Bank/elevens-bank/elk/pipeline/logstash.conf`

---

## 📝 Notes

### Log Format (JSON)
Your microservices use **Logback with JSON encoder**, which produces logs like:
```json
{
  "@timestamp": "2026-01-11T10:07:29.421+05:30",
  "@version": "1",
  "message": "Customer account created successfully",
  "logger_name": "com.customers.controller.CustomerController",
  "thread_name": "http-nio-8080-exec-1",
  "level": "INFO",
  "level_value": 20000
}
```

### Index Naming Convention
- **Pattern**: `elevens-bank-logs-{service_name}-{YYYY.MM.dd}`
- **Examples**:
  - `elevens-bank-logs-account-service-2026.01.11`
  - `elevens-bank-logs-auth-service-2026.01.11`
- **Benefit**: Daily indices make it easier to manage and delete old logs

### Docker Compose Resource Limits
Current configuration (see `docker-compose.yml`):
- Elasticsearch: 1.5 CPU, 1GB RAM, 384MB JVM heap
- Logstash: 0.8 CPU, 512MB RAM, 192MB JVM heap  
- Kibana: 0.5 CPU, 512MB RAM

**Adjust if needed** based on your system resources.

---

## ✅ Summary Checklist

- [x] ELK stack running (Elasticsearch, Logstash, Kibana)
- [x] Logstash configured to parse JSON logs
- [x] Sample banking data added (20 transactions)
- [x] Created data view for `banking-transactions*`
- [x] Explored data in Discover
- [x] Created visualizations (pie, bar, metric)
- [ ] Start microservices to generate real logs
- [ ] Create data view for `elevens-bank-logs-*`
- [ ] Build dashboards for microservices monitoring
- [ ] Set up alerts for ERROR logs

---

**Last Updated**: January 11, 2026  
**Maintained By**: Shrikar  
**Version**: 1.0

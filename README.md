# ACS - Advanced Commit Search

A powerful semantic search system for exploring commit messages from Git repositories using vector embeddings and natural language processing.

## Overview

ACS (Advanced Commit Search) is a sophisticated tool that enables semantic search across commit messages from GitHub repositories. It leverages vector embeddings and the Qdrant vector database to provide intelligent, context-aware search capabilities that go beyond simple keyword matching.

The system processes commit messages from XML data sources, converts them to semantic embeddings using state-of-the-art sentence transformers, and stores them in a high-performance vector database for fast similarity searches.

## Features

- **Semantic Search**: Find relevant commits based on meaning and context, not just keywords
- **Vector Embeddings**: Uses sentence transformers to create high-quality semantic representations
- **Fast Vector Database**: Powered by Qdrant for efficient similarity search operations
- **SQL Analytics Layer**: SQLite database for complex relational queries and statistical analysis
- **Hybrid Search Architecture**: Combines vector similarity with SQL-based filtering and aggregation
- **Multiple Repository Support**: Process and search across multiple GitHub repositories
- **XML Data Processing**: Handles structured commit data in XML format
- **Interactive Jupyter Environment**: Complete development and analysis environment
- **Batch Processing**: Optimized for handling large datasets efficiently

## Architecture

The system consists of several key components:

### Core Components

1. **Data Processing Pipeline**
   - XML parsing for commit message extraction
   - Text preprocessing and tokenization using NLTK
   - Sentence-level embeddings generation

2. **Vector Database (Qdrant)**
   - High-performance vector storage and retrieval
   - GPU acceleration support
   - Scalable similarity search capabilities

3. **Jupyter Notebook Interface**
   - Interactive development environment
   - Data science stack with pandas, numpy, matplotlib
   - Real-time analysis and visualization

4. **SQL Analytics Layer (SQLite)**
   - Relational database for structured commit metadata
   - Complex queries for statistical analysis and reporting
   - Multi-dimensional filtering and aggregation capabilities
   - Author productivity analysis and time-based trends

### Technology Stack

- **Python**: Core application logic
- **Qdrant**: Vector database for semantic search
- **Sentence Transformers**: Neural embedding models
- **NLTK**: Natural language processing toolkit
- **Docker**: Containerized deployment
- **Jupyter**: Interactive computing environment
- **SQLite**: Relational database for analytics and complex queries

### SQL Analytics & Relational Queries

ACS implements a sophisticated dual-database architecture that combines the power of vector similarity search with traditional SQL analytics:

#### Database Schema

**Repositories Table:**

```sql
CREATE TABLE repositories (
    repository_url TEXT PRIMARY KEY,
    repository_name TEXT NOT NULL
);
```

**Commits Table:**

```sql
CREATE TABLE commits (
    hash TEXT NOT NULL,
    author TEXT NOT NULL,
    date TEXT NOT NULL,
    message TEXT NOT NULL,
    repository_url TEXT NOT NULL,
    commit_similarity_score REAL,
    PRIMARY KEY (repository_url, hash),
    FOREIGN KEY (repository_url) REFERENCES repositories (repository_url)
);
```

#### Advanced SQL Analytics

##### Author Productivity Analysis

- Analyze developer contributions across repositories
- Calculate average similarity scores per author
- Identify patterns in commit quality and relevance
- Track contributor engagement metrics

```sql
SELECT author, COUNT(*) as commits, AVG(commit_similarity_score) as avg_score
FROM commits WHERE commit_similarity_score IS NOT NULL
GROUP BY author ORDER BY avg_score DESC;
```

##### Time-Based Trend Analysis

- Monthly and yearly commit patterns
- Seasonal variations in bug fix activity
- Repository evolution over time
- Quality trends and improvements

##### Repository Quality Metrics

- Bug fix percentage calculations
- Developer diversity analysis
- Commit quality distributions
- Cross-repository comparisons

##### Multi-Dimensional Filtering

- Combine semantic similarity with metadata filters
- Date range queries with relevance scoring
- Author-specific pattern analysis
- Repository-focused investigations

#### Hybrid Search Capabilities

The system uniquely combines:

1. **Vector Similarity**: Find semantically related commits using neural embeddings
2. **SQL Filtering**: Apply precise filters on metadata (author, date, repository)
3. **Statistical Analysis**: Aggregate and analyze patterns across large datasets
4. **Relational Joins**: Cross-reference data between repositories and commits

#### SQL Query Examples

**Repository Comparison:**

```sql
SELECT r.repository_name, 
       COUNT(*) as total_commits,
       AVG(c.commit_similarity_score) as avg_relevance
FROM commits c JOIN repositories r ON c.repository_url = r.repository_url
WHERE c.commit_similarity_score > 0.4
GROUP BY r.repository_name;
```

**Time Series Analysis:**

```sql
SELECT substr(date, 1, 7) as month, 
       COUNT(*) as relevant_commits,
       AVG(commit_similarity_score) as quality_score
FROM commits 
WHERE commit_similarity_score > 0.5
GROUP BY substr(date, 1, 7)
ORDER BY month DESC;
```

### XML Technologies & Validation

The project uses a comprehensive XML-based approach for data processing and validation:

#### XML Schema Definition (XSD)

- **repository-commit-schema.xsd**: Defines the complete XML structure for repository commit data
- **Schema Features**:
  - Strong type validation for Git SHA-1 hashes (40 hexadecimal characters)
  - Email format validation with regex patterns
  - ISO datetime format validation for commit timestamps
  - CDATA sections for preserving commit message formatting
  - Comprehensive documentation annotations

#### XML Processing Tools

- **xmllint**: Used for XML validation and schema compliance checking
  - Validates XML files against the XSD schema
  - Provides detailed error reporting for malformed data
  - Ensures data integrity before processing

#### Data Export & Validation Scripts

- **export_commit_messages.sh**:
  - Generates well-formed XML from Git repositories
  - Creates structured XML with proper CDATA wrapping for commit messages
  - Handles special characters and preserves original formatting
  - Supports multiple repository processing with consistent XML structure

- **validate-xml.sh**:
  - Automated XML validation against the schema
  - Batch validation of multiple XML files
  - Colorized output for validation results
  - Detailed error reporting for debugging

#### XML Structure Standards

- **Namespace Management**: Proper XML namespace declarations
- **Character Encoding**: UTF-8 encoding for international character support
- **Data Integrity**: Schema-enforced validation for all commit metadata
- **Extensibility**: Well-designed schema allows for future enhancements

## Repository Structure

```text
acs/
├── app/                           # Main application code
│   ├── app.ipynb                 # Jupyter notebook with main logic
│   ├── requirements.txt          # Python dependencies
│   ├── commit_messages.db        # SQLite database for metadata
│   ├── XML_commit_messages/      # Source XML data files
│   ├── export_commit_messages.sh # Data export utilities
│   ├── validate-xml.sh          # XML validation scripts
│   └── repository-commit-schema.xsd # XML schema definition
├── qdrant_storage/               # Vector database storage
├── docker-compose.yml            # Container orchestration
└── README.md                     # Project documentation
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- At least 8GB RAM recommended
- NGPU support (optional, for enhanced performance)

### Setup and Running

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd acs
   ```

2. **Start the services**

   ```bash
   docker-compose up -d
   ```

3. **Access the Jupyter environment**
   - Open your browser to `http://localhost:8888`
   - Navigate to the `work` directory
   - Open `app.ipynb` to start working

4. **Access Qdrant dashboard** (optional)
   - Browse to `http://localhost:6333/dashboard`
   - Monitor vector database operations

### Basic Usage

1. **Load and Process Data**: The system can process XML files containing commit messages from GitHub repositories

2. **Generate Embeddings**: Commit messages are converted to vector embeddings using sentence transformers

3. **Store in Vector Database**: Embeddings are stored in Qdrant for fast similarity search

4. **Perform Semantic Search**: Query the system using natural language to find relevant commits

## Configuration

### Environment Variables

- `VECTOR_DB_INSERT_BATCH_SIZE`: Controls batch size for vector database operations (default: 100)

### Customization

- **Embedding Models**: Modify the sentence transformer model in the notebook
- **Search Parameters**: Adjust similarity thresholds and result limits
- **Data Sources**: Add new XML data files to the XML_commit_messages directory

## Data Format

The system expects commit data in XML format following this structure:

```xml
<repository>
    <n>repository-name</n>
    <url>repository-url</url>
    <commits>
        <commit>
            <hash>commit-hash</hash>
            <author>author-email</author>
            <date>commit-date</date>
            <message><![CDATA[commit message]]></message>
        </commit>
    </commits>
</repository>
```

## Performance

- **Batch Processing**: Optimized for large datasets with configurable batch sizes
- **GPU Acceleration**: Optional GPU support for faster embedding generation
- **Vector Database**: Qdrant provides sub-millisecond search times
- **Memory Efficient**: Streaming processing for large XML files

## Use Cases

- **Code Archaeology**: Find commits related to specific features or bug fixes
- **Development Insights**: Analyze commit patterns and development trends
- **Knowledge Discovery**: Uncover relationships between different parts of a codebase
- **Research**: Study software development practices across repositories

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

See the LICENSE file for details.

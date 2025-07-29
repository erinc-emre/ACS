VECTOR_DB_RESULT_LIMIT = 5
VECTOR_DB_INSERT_BATCH_SIZE = 100


"""
# ===== Download Commit Messages ======

import subprocess

result = subprocess.run(['bash', 'export_commit_messages.sh'], capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print("Error downloading commit messages:", result.stderr)
    exit(1)
print("Commit messages downloaded successfully.")

# ===== Validate XML File =====


result = subprocess.run(['bash', 'validate-xml.sh'], capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print("Error validating XML file:", result.stderr)
    exit(1)
"""

# ===== Paragraph to Sentence =======
import nltk
from nltk.tokenize import sent_tokenize
nltk.download('punkt')
nltk.download('punkt_tab')
import re

def paragraph_to_sentences(paragraph):
    # Split by two or more consecutive newlines
    parts = re.split(r'\n{2,}', paragraph)
    sentences = []
    for part in parts:
        # Replace single newlines with spaces
        part = part.replace('\n', ' ')
        sentences.extend(sent_tokenize(part))
    return sentences

# ===== Parse the XML =====
import xml.etree.ElementTree as ET
from tqdm import tqdm
import os


def parse_commits(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    repo = root.find('repository')
    repo_url = repo.find('url').text if repo is not None else None
    repo_name = repo.find('name').text if repo is not None else None
    commits = []
    for commit in tqdm(root.findall('.//commit'), desc="Parsing commits"):
        message = commit.find('message').text
        author = commit.find('author').text
        date = commit.find('date').text
        hash = commit.find('hash').text
        commits.append({"message": message,
                        "author": author,
                        "date": date,
                        "hash": hash,
                        "repo_url": repo_url,
                        "repo_name": repo_name})
    return commits


commits = []
xml_dir = 'XML_commit_messages'
for filename in os.listdir(xml_dir):
    if filename.endswith('.xml'):
        file_path = os.path.join(xml_dir, filename)
        commits.extend(parse_commits(file_path))

# ===== Generate Embeddings =====
from sentence_transformers import SentenceTransformer

model_name = 'multi-qa-MiniLM-L6-cos-v1'
print(f"Loading model {model_name} ...")
model = SentenceTransformer(model_name)  # better for query → doc
print("Generating embeddings...")

# ===== Set Up Qdrant & Store Embeddings =====
from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams, Distance, PointStruct

client = QdrantClient(host='localhost', port=6333)

if not client.collection_exists(collection_name="commits"):
    client.create_collection(
        collection_name="commits",
        vectors_config=VectorParams(size=384, distance=Distance.COSINE),
    )
else:
    client.delete_collection(collection_name="commits")
    client.create_collection(
        collection_name="commits",
        vectors_config=VectorParams(size=384, distance=Distance.COSINE),
    )


points = [PointStruct(id=i, vector=model.encode(c['message'], convert_to_numpy=True).tolist(), payload={"commit-hash": c['hash'], "author": c['author'], "date": c['date'], "message": c['message']})
          for i, c in enumerate(commits)]


for i in tqdm(range(0, len(points), VECTOR_DB_INSERT_BATCH_SIZE), desc="Upserting to Qdrant"):
    batch = points[i:i+VECTOR_DB_INSERT_BATCH_SIZE]
    client.upsert(collection_name="commits", points=batch)


# ===== Embed User Input =====
def embed_user_query(query):
    return model.encode(query, convert_to_numpy=True)

# ===== Search Qdrant for Similar Commit Messages =====
from qdrant_client.http.models import Filter, FieldCondition, MatchValue


def search_similar_commit(query):
    vector = embed_user_query(query)
    results = client.search(
        collection_name="commits",
        query_vector=vector.tolist(),
        limit=VECTOR_DB_RESULT_LIMIT,
        with_payload=True,
    )
    if not results:
        return "No similar commit found."
    return results

# ===== Example Usage =====
x = search_similar_commit("bug fix")
print("============= Search Results =============")
print(x)
print("===========================================")


# ===== SQLite Database Setup =====
import sqlite3

conn = sqlite3.connect('commit_messages.db')
cursor = conn.cursor()

# ===== Drop existing tables to ensure clean schema =====
cursor.execute('DROP TABLE IF EXISTS commits')
cursor.execute('DROP TABLE IF EXISTS repositories')


# ===== Create table for repositories =====
cursor.execute('''
    CREATE TABLE IF NOT EXISTS repositories (
        repository_url TEXT PRIMARY KEY,
        repository_name TEXT NOT NULL
    )
''')

# ===== Create table for commits =====
cursor.execute('''
    CREATE TABLE IF NOT EXISTS commits (
        hash TEXT NOT NULL,
        author TEXT NOT NULL,
        date TEXT NOT NULL,
        message TEXT NOT NULL,
        repository_url TEXT NOT NULL,
        PRIMARY KEY (repository_url, hash),
        FOREIGN KEY (repository_url) REFERENCES repositories (repository_url)
    )
''')

# ===== Insert data from the commits list =====
for commit in commits:
    # Insert repository
    cursor.execute(
        'INSERT OR IGNORE INTO repositories (repository_url, repository_name) VALUES (?, ?)',
        (commit['repo_url'], commit['repo_name'])
    )
    
    # Insert commit
    cursor.execute(
        'INSERT OR IGNORE INTO commits (hash, author, date, message, repository_url) VALUES (?, ?, ?, ?, ?)',
        (commit['hash'], commit['author'], commit['date'], commit['message'], commit['repo_url'])
    )

conn.commit()
conn.close()
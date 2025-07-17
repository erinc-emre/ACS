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

def parse_commit_messages(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    commits = []
    for commit in tqdm(root.findall('.//commit'), desc="Parsing commits"):
        message = commit.find('message').text
        # Split message into sentences and add each sentence as a commit
        sentences = paragraph_to_sentences(message.strip())
        commits.extend(sentences)
    return commits

commit_messages = parse_commit_messages('XML_commit_messages/carbon-lang_commits.xml')

# ===== Generate Embeddings =====
from sentence_transformers import SentenceTransformer

model_name = 'multi-qa-MiniLM-L6-cos-v1'
print(f"Loading model {model_name} ...")
model = SentenceTransformer(model_name)  # better for query → doc
print("Generating embeddings...")
embeddings = model.encode(commit_messages, convert_to_numpy=True)


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

points = [PointStruct(id=i, vector=vec.tolist(), payload={"message": msg})
          for i, (vec, msg) in enumerate(zip(embeddings, commit_messages))]


BATCH_SIZE = 100
for i in tqdm(range(0, len(points), BATCH_SIZE), desc="Upserting to Qdrant"):
    batch = points[i:i+BATCH_SIZE]
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
        limit=5,
        with_payload=True,
    )
    if not results:
        return "No similar commit found."
    return results

# ===== Example Usage =====
x = search_similar_commit("bug fix")
print(x)


# ===== SQLite Database Setup =====
import sqlite3

conn = sqlite3.connect('commit_messages.db')
cursor = conn.cursor()

# Create table for commit messages
cursor.execute('''
    CREATE TABLE IF NOT EXISTS commits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL
    )
''')

# Insert commit messages from XML
cursor.executemany(
    'INSERT INTO commits (message) VALUES (?)',
    [(msg,) for msg in commit_messages]
)

conn.commit()
conn.close()
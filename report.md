
<div align="center">
  <big><b>ACS: A System for Semantic Analysis of Software Repository Commit Messages</b></big>
</div>
<div align="center">
  Erin C., Gemini Research Group
</div>

<br>

**_Abstract_—This paper presents the Advanced Commit Search (ACS) system, a comprehensive platform for the semantic analysis of commit messages from Git repositories. Traditional methods for searching software history rely on keyword matching, which often fails to capture the conceptual intent behind code changes. ACS addresses this limitation by implementing a sophisticated data pipeline that transforms unstructured commit messages into high-dimensional vector embeddings. These vectors are stored and indexed in a specialized vector database, enabling powerful semantic search capabilities. This report details the system's architecture, covering the data collection and structuring via XML schemas, the processing pipeline involving sentence-transformer models for vectorization, and the hybrid data access model that combines semantic similarity search with relational SQL analytics. Furthermore, we explore the adaptability of the core technology by postulating an alternative use case with a different dataset, demonstrating the system's broader applicability beyond software engineering.**

<br>

**_Keywords—semantic search, vector database, natural language processing, software repository mining, git, sentence transformers, Qdrant._**

### I. INTRODUCTION

Mining software repositories is a critical activity for understanding the evolution of a software project, identifying the origin of bugs, and analyzing developer contributions. The commit history, a chronological log of all changes, is a rich source of this information. However, the sheer volume and unstructured nature of commit messages make it challenging to perform effective queries. Simple keyword-based searches are often inadequate, as they cannot comprehend synonyms, related concepts, or the underlying intent of a developer's message. For instance, a search for "fix authentication bug" might miss relevant commits logged with messages like "resolved login issue" or "patched security vulnerability in user session handling."

To overcome these challenges, we developed the Advanced Commit Search (ACS) system. ACS is designed to move beyond lexical search and enable true semantic understanding of commit histories. By leveraging state-of-the-art natural language processing (NLP) models and a high-performance vector database, ACS allows users to query the commit history using natural language, retrieving results based on conceptual similarity rather than keyword overlap.

This paper provides a comprehensive overview of the ACS project. Section II details the system's architecture, broken down into its three primary stages: data collection, data processing, and data access. Section III discusses the practical usage and deployment of the system. Section IV presents a thought experiment, illustrating how the technological foundation of ACS could be repurposed for a completely different domain by altering the dataset. Finally, Section V concludes the report and Section VI provides the references.

### II. SYSTEM OVERVIEW

The architecture of ACS is designed as a modular pipeline, ensuring that each stage of data handling is distinct and efficient. The system is containerized using Docker, orchestrating a Qdrant vector database and a Jupyter Lab environment for data processing and analysis.

#### A. Data Collection and Structuring

The first stage in the ACS pipeline is the collection and standardization of data from Git repositories. Raw `git log` output is inherently unstructured text, which is unsuitable for robust data processing. To address this, we implemented a structured data extraction process.

1)  _Extraction_: A shell script, `export_commit_messages.sh`, is used to iterate through a Git repository's history. It uses the `git log` command with a custom format flag to extract key metadata for each commit: the SHA-1 hash, author's email, commit date, and the full commit message.

2)  _Structuring_: The extracted data is then transformed into a well-defined XML format. Each repository's commit history is encapsulated within a single XML file. This approach ensures data integrity and facilitates interoperability.

3)  _Schema Validation_: To enforce a consistent data structure, we defined an XML Schema Definition (XSD) in the `repository-commit-schema.xsd` file. This schema specifies the exact format for each data field, including data types and constraints (e.g., the precise 40-character pattern for a Git hash). A validation script, `validate-xml.sh`, uses `xmllint` to verify that each generated XML file conforms to this schema before it is admitted into the processing stage. This step is crucial for preventing data quality issues downstream.

The importance of this schema-first approach cannot be overstated. During development, the XSD validation layer proved crucial in maintaining data integrity. For instance, an early data export contained a commit message with an embedded null character (an unrecognized, non-printable character), as illustrated in Fig. 1. Such a character is often invisible to the naked eye but can cause significant downstream issues, including parser failures in the Python application, data corruption in the SQLite database, or even potential security vulnerabilities like null byte injection. By validating every XML file against the strict XSD schema *before* any processing, this malformed entry was immediately flagged and rejected. This early detection prevented the erroneous data from being ingested, saving significant computational resources that would have been wasted on a failed processing attempt and mitigating potential application-level errors or attacks.

For detailed information on the XML data structure, the `README-schema.md` file provides a comprehensive reference.

#### B. Data Processing and Enrichment

Once the commit data is collected and validated, it moves to the core of the ACS system: the processing and enrichment pipeline. This stage is managed within a Jupyter Notebook (`app.ipynb`) and leverages several key Python libraries.

1)  _Parsing_: The validated XML files are parsed to extract the commit metadata and messages. The data is loaded into Python lists for efficient manipulation.

2)  _Vectorization_: The semantic power of ACS is derived from this step. We use the `sentence-transformers` library, which provides pre-trained NLP models capable of converting text into meaningful numerical representations (vectors or embeddings). Each commit message is passed through a model (e.g., `all-MiniLM-L6-v2`), which outputs a 384-dimensional vector that captures the semantic essence of the message. Messages with similar meanings will have vectors that are close to each other in the high-dimensional vector space.

3)  _Storage_: The enriched data, consisting of the original commit metadata and its corresponding vector embedding, is stored in two separate but complementary databases:
    *   **Qdrant:** A high-performance vector database used to store the embeddings. Qdrant is specifically designed for efficient similarity search, allowing it to find the "nearest" vectors to a given query vector almost instantaneously.
    *   **SQLite:** A relational database used to store the commit metadata (hash, author, date, etc.). This allows for traditional SQL-based queries, filtering, and aggregation, which complements the semantic search capability.

This dual-database approach enables a powerful hybrid search model, which is discussed in the next section.

#### C. Data Access and Querying

The final stage of the pipeline is providing access to the processed data. ACS offers a flexible and powerful querying model that allows users to explore the commit history in ways that were not possible with traditional tools.

1)  _Semantic Search_: The primary access method is through semantic search. A user provides a natural language query (e.g., "how was the memory leak fixed?"). This query string is converted into a vector using the same sentence-transformer model. The resulting query vector is then sent to the Qdrant database, which performs a similarity search (e.g., using cosine similarity) to find the commit message vectors that are closest to it. The system then returns the corresponding commits, ranked by their semantic relevance to the query.

2)  _Hybrid Search_: The true power of ACS lies in its ability to combine semantic search with structured filtering. Because the metadata is stored in a separate SQL database, a user can construct highly specific hybrid queries. For example, a user could perform a semantic search for "refactoring the rendering engine" and then filter the results to only include commits made by a specific author within a certain date range. This is achieved by first getting a list of relevant commit hashes from Qdrant and then using those hashes in a `WHERE` clause in a SQL query executed against the SQLite database.

3)  _Analytics and Insights_: The relational data stored in SQLite also allows for broader analytical queries. One can analyze developer productivity, track the frequency of bug-fix commits over time, or compare commit patterns across different repositories, as demonstrated by the example SQL queries in the last section of the project's notebook and in the `README.md`.

### III. USAGE AND DEPLOYMENT

Users can run the entire ACS system with a single command after cloning the repository: `docker-compose up`. This command leverages Docker to build and run the necessary services in a containerized environment. The primary benefits of this approach are reproducibility and simplicity; it encapsulates all dependencies (such as Python, Qdrant, and Jupyter) and configurations, eliminating complex local setup and ensuring the system runs consistently across different machines.

Once the services are running, the user interacts with the system via a Jupyter Notebook (`app.ipynb`), which is accessible through a web browser. This notebook contains the complete data processing and querying logic. For a complete guide on setup, architecture, and usage, users are encouraged to consult the `README.md` file.

Furthermore, the system is optimized for performance. The Qdrant vector database is configured to utilize NVIDIA GPUs via CUDA, which significantly accelerates vector search operations, making it possible to perform semantic searches over millions of commits with sub-second latency.

### IV. ALTERNATIVE PROJECT SCENARIO

The core technology of ACS—extracting structured text, converting it to semantic vectors, and enabling hybrid search—is highly adaptable. To illustrate this, we can imagine a completely different project that uses the same technological stack but operates on a different dataset.

**Project Idea: Semantic Analysis of Patient Visit Notes**

Consider a healthcare scenario where the goal is to analyze and search through thousands of unstructured patient visit notes from an electronic health record (EHR) system.

*   **Dataset:** Instead of Git commits, the source data would be a collection of patient encounter notes. Each note is a text document containing a doctor's observations, diagnosis, and prescribed treatment.

*   **Data Collection (The "ETL" Phase):**
    *   An extraction script would connect to the EHR system's database or API to pull patient notes.
    *   The data would be structured into an XML format defined by a new XSD, `patient-note.xsd`. The schema would define fields like `patient_id`, `visit_date`, `attending_physician`, `symptoms_reported`, `diagnosis`, and `treatment_plan`. This mirrors the `repository-commit-schema.xsd` but is adapted for the new domain.

*   **Data Processing and Enrichment:**
    *   The pipeline, running in the same Dockerized environment, would parse these XML files.
    *   A domain-specific sentence-transformer model, possibly one fine-tuned on biomedical text (like BioBERT), would be used to vectorize the `symptoms_reported` and `diagnosis` fields. This is analogous to vectorizing commit messages.
    *   The vectors would be stored in Qdrant, while the structured metadata (`patient_id`, `visit_date`, etc.) would be stored in the SQLite database.

*   **Data Access and Use Case:**
    *   **Clinical Research:** A researcher could perform a semantic search like "patients showing signs of early-onset diabetic neuropathy" and find relevant patient notes, even if the notes used varying terminology (e.g., "tingling in extremities," "loss of sensation in feet").
    *   **Diagnostic Support:** A doctor could search for "similar cases to the symptoms presented" to find historical patient records that could inform their current diagnosis.
    *   **Hybrid Analytics:** The system could answer complex queries like: "Find all patients diagnosed with hypertension (SQL filter) who also showed symptoms related to vision problems (semantic search) in the last year (SQL filter)."

This alternative scenario demonstrates that the fundamental architecture of ACS is not tied to software engineering. The pipeline of structured data extraction, vectorization, and hybrid querying is a powerful and flexible paradigm that can be applied to any domain with a large corpus of unstructured text.

### V. CONCLUSION

The Advanced Commit Search (ACS) project successfully demonstrates the power of combining natural language processing, vector databases, and traditional relational databases to unlock new insights from software repositories. By transforming unstructured commit messages into a searchable, semantic format, ACS provides a far more intuitive and powerful tool for developers, managers, and researchers than traditional keyword-based search methods. The system's modular, containerized architecture ensures its robustness and scalability. Furthermore, as explored in the alternative project scenario, the core technological principles of ACS are highly versatile and represent a modern paradigm for building advanced search and analytics systems in any text-rich domain.

### VI. REFERENCES
[1] Qdrant Authors, "Qdrant: Vector Similarity Search Engine," _qdrant.tech_, 2024. [Online]. Available: https://qdrant.tech/documentation/
<br>
[2] N. Reimers and I. Gurevych, "Sentence-BERT: Sentence Embeddings using a Siamese BERT-Network," in _Proceedings of the 2019 Conference on Empirical Methods in Natural Language Processing_, 2019.
<br>
[3] The Python Foundation, "Python Language Reference," _www.python.org_. [Online]. Available: https://www.python.org
<br>
[4] Jupyter Authors, "Jupyter Notebook," _jupyter.org_, 2024. [Online]. Available: https://jupyter.org/
<br>
[5] Docker Inc., "Docker Overview," _docs.docker.com_. [Online]. Available: https://docs.docker.com/get-started/overview/

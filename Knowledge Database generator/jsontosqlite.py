import sqlite3
import json
import os
from pathlib import Path


def create_vector_database(json_path, output_path):
    """
    Convert embeddings JSON file to SQLite database format suitable for Flutter.

    Args:
        json_path (str): Path to the JSON file containing embeddings
        output_path (str): Path where the SQLite database will be saved
    """
    print(f"Starting conversion from {json_path} to {output_path}")

    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # Remove existing database if it exists
    if os.path.exists(output_path):
        os.remove(output_path)
        print(f"Removed existing database at {output_path}")

    # Connect to SQLite database
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()

    # Create table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        embedding TEXT NOT NULL,
        metadata TEXT
    )
    ''')

    # Create index for faster text search
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_text ON documents(text)')

    # Load JSON data
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            embeddings_data = json.load(f)
    except UnicodeDecodeError:
        with open(json_path, 'r', encoding='utf-8-sig') as f:
            embeddings_data = json.load(f)

    print(f"Loaded {len(embeddings_data)} entries from JSON")

    # Prepare data for batch insertion
    batch_size = 500
    entries = []

    for item in embeddings_data:
        # Convert embedding list to JSON string for storage
        embedding_json = json.dumps(item['embedding'])

        # Store any additional metadata as JSON
        metadata = {k: v for k, v in item.items()
                    if k not in ['id', 'text', 'embedding']}
        metadata_json = json.dumps(metadata) if metadata else None

        entries.append((
            item['id'],
            item['text'],
            embedding_json,
            metadata_json
        ))

        # Insert in batches
        if len(entries) >= batch_size:
            cursor.executemany(
                'INSERT INTO documents (id, text, embedding, metadata) VALUES (?, ?, ?, ?)',
                entries
            )
            entries = []
            conn.commit()
            print(f"Processed {cursor.rowcount} entries...")

    # Insert remaining entries
    if entries:
        cursor.executemany(
            'INSERT INTO documents (id, text, embedding, metadata) VALUES (?, ?, ?, ?)',
            entries
        )
        conn.commit()

    # Create views for easy access
    cursor.execute('''
    CREATE VIEW IF NOT EXISTS documents_with_metadata AS
    SELECT 
        id,
        text,
        embedding,
        json_extract(metadata, '$') as metadata_obj
    FROM documents
    ''')

    # Verify the data
    cursor.execute('SELECT COUNT(*) FROM documents')
    count = cursor.fetchone()[0]

    # Get database size
    db_size = os.path.getsize(output_path) / (1024 * 1024)  # Convert to MB

    print(f"\nDatabase creation completed successfully!")
    print(f"Total documents: {count}")
    print(f"Database size: {db_size:.2f} MB")
    print(f"Database saved to: {output_path}")

    # Close connection
    conn.close()


def verify_database(db_path):
    """
    Verify the created database by performing some basic checks.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("\nVerifying database...")

    # Check row count
    cursor.execute('SELECT COUNT(*) FROM documents')
    count = cursor.fetchone()[0]
    print(f"Total rows: {count}")

    # Check a sample entry
    cursor.execute('SELECT * FROM documents LIMIT 1')
    sample = cursor.fetchone()
    if sample:
        print("\nSample entry:")
        print(f"ID: {sample[0]}")
        print(f"Text length: {len(sample[1])} characters")
        embedding = json.loads(sample[2])
        print(f"Embedding dimensions: {len(embedding)}")
        if sample[3]:
            print(f"Metadata: {sample[3]}")

    conn.close()


def main():
    # Configuration
    EMBEDDINGS_JSON = "embeddings.json"  # Your embeddings JSON file
    OUTPUT_DB = "assets/vector_store3.db"  # Output SQLite database

    try:
        # Convert JSON to SQLite
        create_vector_database(EMBEDDINGS_JSON, OUTPUT_DB)

        # Verify the created database
        verify_database(OUTPUT_DB)

    except Exception as e:
        print(f"Error during conversion: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
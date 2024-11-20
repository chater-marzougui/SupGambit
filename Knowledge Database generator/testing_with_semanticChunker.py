import re
import json
import requests
from langchain_community.document_loaders import PyPDFLoader, WebBaseLoader
from langchain_experimental.text_splitter import SemanticChunker
from langchain_community.embeddings import OllamaEmbeddings

# Hugging Face API details
OLLAMA_URL = "http://localhost:11434"

PDF_FILES = ["./9135b.pdf", "./Chessbook - Irving Chernev - Logical Chess - Move by Move.pdf"]
WEB_URLS = [
    "https://www.chess.com/article/view/how-to-set-up-a-chessboard",
    "https://www.chess.com/terms/chess-pieces",
    "https://www.chess.com/terms/check-chess",
    "https://www.chess.com/terms/checkmate-chess",
    "https://www.chess.com/terms/draw-chess",
    "https://www.chess.com/terms/en-passant",
    "https://www.chess.com/terms/pawn-promotion",
    "https://www.chess.com/terms/castling-chess",
]


def get_embedding(text):
    # Use OllamaEmbeddings for consistent embedding generation
    embedder = OllamaEmbeddings(model="mxbai-embed-large", base_url=OLLAMA_URL)
    return embedder.embed_query(text)


def clean_text(text):
    """
    Clean the input text by:
    - Removing newline characters.
    - Removing unreadable or non-ASCII characters.
    - Stripping excess whitespace.
    """
    text = text.replace("\n", " ")  # Replace newlines with spaces
    text = re.sub(r"[^\x20-\x7E]+", " ", text)  # Remove non-ASCII characters
    text = re.sub(r"\s+", " ", text)  # Collapse multiple spaces into one
    return text.strip()  # Remove leading and trailing spaces


# Function to load and extract text from PDFs
def load_pdfs(file_paths):
    combined_text = []
    for file_path in file_paths:
        loader = PyPDFLoader(file_path)
        documents = loader.load()

        # Initialize SemanticChunker
        text_splitter = SemanticChunker(
            OllamaEmbeddings(model="mxbai-embed-large", base_url=OLLAMA_URL),
            breakpoint_threshold_type="percentile"
        )

        # Split documents semantically
        semantic_docs = text_splitter.split_documents(documents)

        for doc in semantic_docs:
            cleaned_content = clean_text(doc.page_content)
            combined_text.append(cleaned_content)

    return combined_text


# Function to load and extract text from web pages
def load_web_pages(urls):
    combined_text = []
    for url in urls:
        loader = WebBaseLoader(url)
        docs = loader.load()

        # Initialize SemanticChunker
        text_splitter = SemanticChunker(
            OllamaEmbeddings(model="mxbai-embed-large", base_url=OLLAMA_URL),
            breakpoint_threshold_type="percentile"
        )

        # Split documents semantically
        semantic_docs = text_splitter.split_documents(docs)

        for doc in semantic_docs:
            cleaned_content = clean_text(doc.page_content)
            combined_text.append(cleaned_content)

    return combined_text


# Combine all text, generate embeddings, and save
def main():
    pdf_texts = load_pdfs(PDF_FILES)
    web_texts = load_web_pages(WEB_URLS)
    all_texts = pdf_texts + web_texts

    embeddings = []
    for idx, text in enumerate(all_texts):
        print(f"Processing text chunk {idx + 1}/{len(all_texts)}...")
        embedding = get_embedding(text)
        embeddings.append({"id": f"text_{idx}", "text": text, "embedding": embedding})

    # Save embeddings to a file
    with open("embeddings.json", "w") as f:
        json.dump(embeddings, f)

    print("Embeddings saved to 'embeddings.json'.")


if __name__ == "__main__":
    main()

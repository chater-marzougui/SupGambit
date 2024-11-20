import json
import re

# Define the file paths
input_file = "embeddings.json"
output_file = "cleaned_embeddings.json"


# Step 1: Define the cleaning function
def clean_text(text):
    # Replace multiple \n with a single \n
    text = re.sub(r'\n+', '\n', text)
    # Remove leading/trailing whitespace
    text = text.strip()

    # Define redundant content patterns to remove
    redundant_patterns = [
        r'(?i)Home\nPlay\n.*?More\n',  # Example regex for "Home Play" menu
        r'Sign Up\nLog In\n',  # Example for sign-up/log-in sections
        r'Chess\.com © \d{4}\n',  # Example for footer
        r'Explore More Chess Terms.*?Chess Pieces\n',  # Example for expandable menus
    ]

    for pattern in redundant_patterns:
        text = re.sub(pattern, '', text, flags=re.DOTALL)

    return text


# Step 2: Read the JSON file
with open(input_file, "r", encoding="utf-8") as file:
    data = json.load(file)

# Step 3: Clean the `text` fields
for item in data:
    if "text" in item:
        item["text"] = clean_text(item["text"])

# Step 4: Save the cleaned JSON to a new file
with open(output_file, "w", encoding="utf-8") as file:
    json.dump(data, file)

print(f"Cleaned JSON saved to {output_file}")

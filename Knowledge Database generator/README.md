<a name="readme-top"></a>
<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]](https://www.linkedin.com/in/chater-marzougui-342125299/)
</div>


# Chess Data Embedding Generator For SMC Challenge TSYP12
<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#features">Features</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project
This project focuses on gathering chess-related data from PDFs and web pages, processing it to generate embeddings, and storing it in a SQL database for efficient management and similarity search. The embeddings are generated using the `mx-bai-large` model served on Ollama.

## Features
- **PDF and Web Scraping:** Extracts text from PDFs and web pages.
- **Text Cleaning and Preprocessing:** Cleans and normalizes extracted content.
- **Embedding Generation:** Uses `mx-bai-large` for vector embeddings.
- **Semantic Chunking:** Splits content semantically for better embedding accuracy.
- **SQL Storage:** Saves data in a SQL database for advanced management.
- **Similarity Search:** Enables similarity-based queries on the data.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/chater-marzougui/chess-data-embedding.git
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Set up Ollama for serving the `mx-bai-large` model locally.
4. Ensure your database is configured and accessible.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

1. Add your PDFs to the project directory and update the `PDF_FILES` list in the code.
2. Add URLs to the `WEB_URLS` list for web scraping.
3. Run the main script to generate embeddings:
   ```bash
   python main.py
   ```
4. Use the JSON-to-SQL converter script to save embeddings into your SQL database:
   ```bash
   python json_to_sql.py
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Chater Marzougui - [@Chater-marzougui][linkedin-url] - chater.mrezgui2002@gmail.com

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/chater-marzougui/chess-data-embedding.svg?style=for-the-badge
[contributors-url]: https://github.com/chater-marzougui/chess-data-embedding/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/chater-marzougui/chess-data-embedding.svg?style=for-the-badge
[forks-url]: https://github.com/chater-marzougui/chess-data-embedding/network/members
[stars-shield]: https://img.shields.io/github/stars/chater-marzougui/chess-data-embedding.svg?style=for-the-badge
[stars-url]: https://github.com/chater-marzougui/chess-data-embedding/stargazers
[issues-shield]: https://img.shields.io/github/issues/chater-marzougui/chess-data-embedding.svg?style=for-the-badge
[issues-url]: https://github.com/chater-marzougui/chess-data-embedding/issues
[license-shield]: https://img.shields.io/github/license/chater-marzougui/chess-data-embedding.svg?style=for-the-badge
[license-url]: https://github.com/chater-marzougui/chess-data-embedding/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/chater-marzougui-342125299


## Ollama Setup

This project uses [Ollama](https://ollama.ai/) to generate embeddings with the `mx-bai-large` model. Follow these steps to set up Ollama:

1. **Install Ollama**  
   Download and install Ollama from their official website: [https://ollama.ai/download](https://ollama.ai/download).

2. **Clone the `mx-bai-large` Model**  
   Open your terminal and run the following command to download the `mx-bai-large` model:
   ```bash
   ollama pull mx-bai-large
   ```

3. **Start the Ollama Server**  
   Serve the model locally by running:
   ```bash
   ollama serve mx-bai-large
   ```
   This will start a local server at `http://localhost:11434` by default.

4. **Verify the Server**  
   Ensure the server is running by accessing `http://localhost:11434` in your browser or sending a test request.

Once the server is running, the application will automatically connect to the embedding service at the specified base URL.

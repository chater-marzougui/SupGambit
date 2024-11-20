# Game Outcome Prediction Project

This repository explores a data-driven approach to predict the likely outcome of a game based on the current state. It includes the steps for data preparation, model creation, and performance analysis, with a focus on explainability and usability.

---

## 📸 Demo and Visuals

- **Model Performance**

- **Demo Video**

---

## 🛠 Features

- **Data Exploration**: Insights into the structure and distribution of game state data.
- **Outcome Prediction**: Predicts the game's outcome based on given inputs.
- **Customizable Architecture**: Easy to adapt the model for different use cases or datasets.

---

## 📂 Repository Structure

- `notebook.ipynb`: Main Jupyter Notebook containing the step-by-step process for data handling and model training.
- `data/`: Placeholder folder for game state data.
- `images/`: Contains all visual resources, like plots and performance graphs.

---

## 📊 Results Summary

The project demonstrates how a machine learning model can achieve high predictive accuracy on sequential game data:
- **Training Accuracy**: `0.9137`
- **Validation Accuracy**: `0.8464`
- **AUC (Validation)**: `0.9530`
- **Loss (Validation)**: `0.4474`

---

## 🤖 AI Model: Bidirectional GRU

The AI component of the project features a **Bidirectional Gated Recurrent Unit (GRU)** model, ideal for sequential data. 

### Model Highlights
1. **Input Layer**: Processes the game state sequence.
2. **Bi-directional GRU Layers**: Captures dependencies in both forward and backward directions.
3. **Dense Layers**: Output probabilities for game outcomes.

### Training Metrics
- **Accuracy**: `0.9137`
- **AUC**: `0.9843`
- **Loss**: `0.2339`

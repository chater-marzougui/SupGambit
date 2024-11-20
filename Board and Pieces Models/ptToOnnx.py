import torch
from ultralytics import YOLO


def convert_yolo_to_onnx(model_path, output_path):
    """
    Convert YOLO model to ONNX format

    Args:
        model_path (str): Path to the trained YOLO .pt model
        output_path (str): Path to save the converted ONNX model
    """
    # Load the YOLO model
    model = YOLO(model_path)

    # Get the underlying PyTorch model
    torch_model = model.model

    # Prepare input tensor (adjust dimensions based on your model's input)
    # Typically for YOLO: [batch_size, channels, height, width]
    batch_size = 1
    channels = 3  # RGB image
    height, width = 640, 640  # Common input size, adjust as needed

    # Create a dummy input
    x = torch.randn(batch_size, channels, height, width)

    try:
        # Export to ONNX
        torch.onnx.export(
            torch_model,
            x,
            output_path,
            export_params=True,
            opset_version=12,
            do_constant_folding=True,
            input_names=["input"],
            output_names=["output"],
            dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
        )
        print(f"Model successfully converted to ONNX: {output_path}")

    except Exception as e:
        print(f"Conversion error: {e}")


# Example usage
if __name__ == "__main__":
    convert_yolo_to_onnx(
        model_path="best_pieces.pt", output_path="chess_pieces_detector.onnx"
    )

from ultralytics import YOLO

from matplotlib.pyplot import figure
import matplotlib.image as image
from matplotlib import pyplot as plt
from matplotlib.patches import Rectangle
import pandas as pd
import numpy as np
from numpy import asarray
from PIL import Image
from shapely.geometry import Point, Polygon

import cv2

from fastapi import FastAPI, File, UploadFile
from fastapi.responses import FileResponse
import shutil
import os
import numpy as np
from io import BytesIO

from fastapi.responses import JSONResponse
import uvicorn


app = FastAPI()

corner_model = YOLO("best_corners.pt")
piece_model = YOLO(r"C:\Lobna\Chess_detection\runs\detect\train20\weights\best.pt")

di = {
    0: "b",
    1: "k",
    2: "n",
    3: "p",
    4: "q",
    5: "r",
    6: "B",
    7: "K",
    8: "N",
    9: "P",
    10: "Q",
    11: "R",
}


def order_points(pts):
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def detect_corners(image):
    results = corner_model.predict(source=image, conf=0.15, iou=0.3)
    boxes = results[0].boxes
    arr = boxes.xywh.cpu().numpy()
    points = arr[:, 0:2]
    return order_points(points)


def four_point_transform(image, pts):
    img = Image.open(image)
    image = np.asarray(img)
    rect = order_points(pts)
    (tl, tr, br, bl) = rect

    widthA = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
    widthB = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
    maxWidth = max(int(widthA), int(widthB))

    heightA = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
    heightB = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
    maxHeight = max(int(heightA), int(heightB))

    dst = np.array(
        [[0, 0], [maxWidth - 1, 0], [maxWidth - 1, maxHeight - 1], [0, maxHeight - 1]],
        dtype="float32",
    )

    M = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(image, M, (maxWidth, maxHeight))
    return Image.fromarray(warped, "RGB"), M


def transform_points(centers, matrix):
    points = np.array(list(centers.keys()), dtype="float32")
    classes = list(centers.values())

    points_homogeneous = np.column_stack((points, np.ones(points.shape[0])))
    transformed_points_homogeneous = np.dot(matrix, points_homogeneous.T).T
    transformed_points = (
        transformed_points_homogeneous[:, :2] / transformed_points_homogeneous[:, 2:3]
    )

    transformed_centers = {
        tuple(transformed_points[i]): classes[i] for i in range(len(classes))
    }

    return transformed_centers


def chess_pieces_detector(image):
    results = piece_model.predict(source=image, conf=0.1, iou=0.3)
    boxes = results[0].boxes
    detections = boxes.xyxy.cpu().numpy()
    class_indices = boxes.cls.cpu().numpy()
    centers = dict()

    for i, box in enumerate(detections):
        x1, y1, x2, y2 = box[:4]
        height = y2 - y1
        y_start = y2 - 0.4 * height
        y_center = (y_start + y2) / 2
        x_center = (x1 + x2) / 2

        class_index = int(class_indices[i])
        centers[(x_center, y_center)] = class_index

    return centers


def is_point_in_square(point, square):
    x, y = point
    n = len(square)
    inside = False
    p1x, p1y = square[0]
    for i in range(n + 1):
        p2x, p2y = square[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside


def connect_square_to_detection(centers, square):
    detected_pieces = []
    for center, det in centers.items():
        x, y = center
        if is_point_in_square((x, y), square):
            piece_type = di.get(det, "1")
            detected_pieces.append(piece_type)

    return detected_pieces[0] if detected_pieces else "1"


def generate_fen(corners, image):
    transformed_image, M = four_point_transform(image, corners)
    centers = chess_pieces_detector(image)
    transformed_centers = transform_points(centers, M)

    x_points = np.linspace(0, transformed_image.size[0], 9)
    y_points = np.linspace(0, transformed_image.size[1], 9)

    FEN_annotation = [
        [(x_points[i], y_points[j], x_points[i + 1], y_points[j + 1]) for i in range(8)]
        for j in range(8)
    ]

    board_FEN = []
    for line in FEN_annotation:
        line_to_FEN = []
        for square in line:
            square_polygon = np.array(
                [
                    (square[0], square[1]),
                    (square[2], square[1]),
                    (square[2], square[3]),
                    (square[0], square[3]),
                ]
            )
            piece_on_square = connect_square_to_detection(
                transformed_centers, square_polygon
            )
            line_to_FEN.append(piece_on_square)

        processed_line = []
        empty_count = 0
        for piece in line_to_FEN:
            if piece == "1":
                empty_count += 1
            else:
                if empty_count > 0:
                    processed_line.append(str(empty_count))
                    empty_count = 0
                processed_line.append(piece)

        if empty_count > 0:
            processed_line.append(str(empty_count))

        board_FEN.append("".join(processed_line))

    return "/".join(board_FEN)


@app.post("/generate-fen/")
async def upload_image(file: UploadFile = File(...)):
    try:
        # Save the uploaded file
        with open("uploaded_image.jpg", "wb") as buffer:
            buffer.write(await file.read())

        # Detect corners
        corners = detect_corners("uploaded_image.jpg")

        # Generate FEN
        fen_code = generate_fen(corners, "uploaded_image.jpg")

        os.remove("uploaded_image.jpg")

        return JSONResponse(
            content={
                "fen": fen_code,
                "lichess_link": f"https://lichess.org/analysis/{fen_code}",
            }
        )

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


if __name__ == "__main__":

    uvicorn.run(app, host="0.0.0.0", port=8000)
